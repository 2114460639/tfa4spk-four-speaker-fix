# tfa4spk - 小新Pad Pro 2023 四扬声器修复模块

修复 **联想小新Pad Pro 2023 (TB371FC, 骁龙870)** 刷入 HyperOS(澎湃OS) 后四扬声器失效的问题，并让 **四个屏幕方向** 下左右声道始终正确。

## 问题根因

刷入澎湃OS 后，四颗 TFA9894 功放的 I2C 寄存器 `reg23`（通道槽选择）被驱动在每个播放会话开始时重置为错误的默认值，导致其中两颗功放（右下 0x35、左下 0x36）落到空槽，只有左上(0x34)和右上(0x37)发声。

- I2C 总线：`i2c-6`
- 四颗 TFA9894 地址：`0x34`(左上)、`0x35`(右下)、`0x36`(左下)、`0x37`(右上)

## 修复原理

守护进程每隔 2 秒检查一次：
1. 音频是否正在播放（`PRI_TDM_RX_0 Audio Mixer MultiMedia1` = On）
2. 读取当前屏幕方向（`dumpsys window` 的 `mDisplayRotation`）
3. 按方向把四颗功放 reg23 改写为对应目标值

守护只在"播放中且 reg23 偏离该方向的目标值"时才改写，播放会话中 reg23 保持稳定，写一次即可维持整个会话。

## 四方向声道映射（视觉左=L 低音 440Hz，视觉右=R 高音 880Hz）

| 屏幕方向 | 充电口 | mDisplayRotation | reg23 目标 |
|---------|--------|-----------------|-----------|
| 竖屏 | 朝下 | ROTATION_0 | 34/35=slot1, 36/37=slot0 |
| 竖屏 | 朝上 | ROTATION_180 | 34/35=slot0, 36/37=slot1 |
| 横屏 | 朝右 | ROTATION_90 | 全部 slot0 |
| 横屏 | 朝左 | ROTATION_270 | 全部 slot1 |

其中 `slot0` 低字节 = `0x10`（reg23=0x0410），`slot1` 低字节 = `0x01`（reg23=0x0401）。

守护自动检测方向变化并即时改写，无需重启播放或手动切换。

## 安装

1. 平板已 Root 并安装 **Magisk**（建议 27+，本机验证 30.7）。
2. 把 `tfa4spk-four-speaker-fix.zip` 推送到平板，例如：
   ```sh
   adb push tfa4spk-four-speaker-fix.zip /sdcard/
   ```
3. 打开 Magisk App → 模块 → **从本地安装** → 选择该 zip。
4. **重启**平板。

重启后守护进程自动启动（Magisk `service.sh`，late_start 阶段，sleep 15 秒等音频 HAL 就绪）。

## 验证

安装后重启，播放任意音频并旋转屏幕，确认四个方向下四颗功放全部发声且声道正确：
- 竖屏充电口朝下/朝上：35/36=左声道，34/37=右声道
- 横屏充电口朝右/朝左：34/36=左声道，35/37=右声道

守护日志（若有问题可查看）：
```
/data/adb/modules/tfa4spk/daemon.log
```
正常日志应包含：
```
tfa4spk daemon v1.4 started
rotation change -> ROTATION_xxx, rewrite
playback active, reg23 deviates -> rewrite ROTATION_xxx
```

## 同型号适用性

**适用于所有 TB371FC 硬件版本**，因为：
- 四颗 TFA9894 的 I2C 地址（0x34/0x35/0x36/0x37）和总线（i2c-6）由硬件定义，同型号相同。
- 声道路由和驱动重置行为由 ROM/内核决定，刷入相同 HyperOS 版本即一致。

**唯一的前提**：刷入的 HyperOS 系统必须使用相同的 TFA9894 驱动行为（即把 reg23 重置为错误的 slot2）。若某版本系统已自行修复此问题，该模块不会造成损害（守护只在"偏离目标且播放中"时才改写）。

## 移除

Magisk App → 模块 → 关闭或删除该模块 → 重启。
