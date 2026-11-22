#!/system/bin/sh
# tfa4spk daemon v1.4: monitor playback + display rotation, force correct reg23
#   ROTATION_0   (portrait,  charging DOWN): 34/35=slot1, 36/37=slot0
#   ROTATION_180 (portrait,  charging UP):   34/35=slot0, 36/37=slot1
#   ROTATION_90  (landscape, charging RIGHT):all=slot0
#   ROTATION_270 (landscape, charging LEFT): all=slot1
# Keeps visual-left=L(440Hz), visual-right=R(880Hz) in ALL four orientations.
LOG=/data/adb/modules/tfa4spk/daemon.log
bus=6

# write one amp reg23 low byte; slot 0=0x10, 1=0x01
w_amp() {
  i2ctransfer -f -y $bus w3@$1 0x23 0x04 $2 >/dev/null 2>&1
}

# write per-rotation target reg23
write_rot() {
  local rot=$1
  case "$rot" in
    ROTATION_0)   # portrait charging down: 34/35 slot1, 36/37 slot0
      w_amp 0x34 0x01; w_amp 0x35 0x01; w_amp 0x36 0x10; w_amp 0x37 0x10
      ;;
    ROTATION_180) # portrait charging up: 34/35 slot0, 36/37 slot1
      w_amp 0x34 0x10; w_amp 0x35 0x10; w_amp 0x36 0x01; w_amp 0x37 0x01
      ;;
    ROTATION_270) # landscape charging left: all slot1
      w_amp 0x34 0x01; w_amp 0x35 0x01; w_amp 0x36 0x01; w_amp 0x37 0x01
      ;;
    *)            # ROTATION_90 default landscape charging right: all slot0
      w_amp 0x34 0x10; w_amp 0x35 0x10; w_amp 0x36 0x10; w_amp 0x37 0x10
      ;;
  esac
}

# current rotation name
cur_rot() {
  dumpsys window 2>/dev/null | grep -m1 'mDisplayRotation=' | grep -oE 'ROTATION_[0-9]+' | head -1
}

# read one amp reg23 low byte
r_amp() {
  i2ctransfer -f -y $bus w1@$1 0x23 r2 2>/dev/null | grep -oE '0x[0-9a-f]{2}' | tail -1
}

# does any amp reg23 differ from rotation target? 0=needs fix
needs_fix() {
  local rot=$1
  case "$rot" in
    ROTATION_0)
      [ "$(r_amp 0x34)" != "0x01" ] && return 0
      [ "$(r_amp 0x35)" != "0x01" ] && return 0
      [ "$(r_amp 0x36)" != "0x10" ] && return 0
      [ "$(r_amp 0x37)" != "0x10" ] && return 0
      ;;
    ROTATION_180)
      [ "$(r_amp 0x34)" != "0x10" ] && return 0
      [ "$(r_amp 0x35)" != "0x10" ] && return 0
      [ "$(r_amp 0x36)" != "0x01" ] && return 0
      [ "$(r_amp 0x37)" != "0x01" ] && return 0
      ;;
    ROTATION_270)
      [ "$(r_amp 0x34)" != "0x01" ] && return 0
      [ "$(r_amp 0x35)" != "0x01" ] && return 0
      [ "$(r_amp 0x36)" != "0x01" ] && return 0
      [ "$(r_amp 0x37)" != "0x01" ] && return 0
      ;;
    *)
      [ "$(r_amp 0x34)" != "0x10" ] && return 0
      [ "$(r_amp 0x35)" != "0x10" ] && return 0
      [ "$(r_amp 0x36)" != "0x10" ] && return 0
      [ "$(r_amp 0x37)" != "0x10" ] && return 0
      ;;
  esac
  return 1
}

echo "[$(date +%s)] tfa4spk daemon v1.4 started" >> $LOG
last_rot=""
while true; do
  playing=$(tinymix 'PRI_TDM_RX_0 Audio Mixer MultiMedia1' 2>/dev/null | grep -o 'On' | head -1)
  if [ "$playing" = "On" ]; then
    rot=$(cur_rot)
    if [ "$rot" != "$last_rot" ]; then
      echo "[$(date +%s)] rotation change -> $rot, rewrite" >> $LOG
      write_rot "$rot"
      last_rot=$rot
    elif needs_fix "$rot"; then
      echo "[$(date +%s)] playback active, reg23 deviates -> rewrite $rot" >> $LOG
      write_rot "$rot"
    fi
  else
    last_rot=""
  fi
  sleep 2
done
