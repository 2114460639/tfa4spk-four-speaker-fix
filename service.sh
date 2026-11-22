#!/system/bin/sh
# Magisk service.sh - start tfa4spk daemon in late_start service phase
DAEMON=/data/adb/modules/tfa4spk/tfa4spk_daemon.sh
if [ -f "$DAEMON" ]; then
  chmod +x "$DAEMON"
  # give audio HAL time to initialize, then start daemon
  sleep 15
  "$DAEMON" >/dev/null 2>&1 &
fi
