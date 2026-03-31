# Bluefox_NX1_optimized

一个面向 Android 热点中继场景的 KernelSU 模块，目标是：

- 提升多设备并发下的网络稳定性
- 降低息屏断流和扫描抖动
- 提供可视化开关控制
- 在游戏场景下通过应用白名单启用 GPU 高性能策略，退出后自动回到省电策略

## 核心功能

1. Backlog 4096
   - 提升 TCP 并发队列能力，缓解多设备中继阻塞。
2. Awake 休眠锁
   - 防止息屏后 Wi-Fi 低功耗导致的断流或降速。
3. ZeroScan 零扫描
   - 关闭后台扫描，减少周期性网络抖动。
4. 代理接管 (Tethering)
   - 将热点侧流量转发到本机 VPN 接口。
5. DNS 净化
   - 将 53 端口流量重定向到 223.5.5.5。
6. BBR 抢占模式
   - BBR / Cubic 切换（切换后需重新开关一次热点使全量连接生效）。
7. GPU 脱僵白名单
   - 仅对白名单应用激活高性能 GPU 策略，日常自动回到省电策略。
8. 图形化白名单权限列表
   - 在 WebUI 勾选应用即可加入白名单，取消勾选即移除。

## 项目结构

```text
Bluefox_NX1_optimized/
  action.sh           # 模块动作入口，提示用户从 KernelSU WebUI 进入
  service.sh          # 核心守护脚本（每 30 秒轮询并应用策略）
  module.prop         # 模块元数据
  build.bat           # Windows 一键打包 + 推送脚本
  DEVLOG.md           # 开发日志与规则
  webroot/
    index.html        # WebUI 前端
```

## 环境要求

1. Android 设备，已获取 root。
2. 已安装 KernelSU，且支持模块 WebUI。
3. 设备具备基础命令能力：`sh`、`pm`、`settings`、`iptables`、`dumpsys`。
4. Windows 侧构建与推送需要可用的 `adb` 和 `tar.exe`。

## 安装与使用

### 方式 A：KernelSU 管理器直接刷入

1. 准备模块 zip。
2. 在 KernelSU 管理器中安装模块。
3. 重启设备。
4. 进入模块的 WebUI 页面进行开关配置。

### 方式 B：使用 build.bat 一键打包并推送

`build.bat` 执行流程：

1. 从 `module.prop` 读取版本号。
2. 清理电脑目录中旧的 `Bluefox*.zip`。
3. 打包 `module.prop`、`service.sh`、`action.sh`、`webroot`。
4. 清理手机 `/sdcard/Download` 下旧的 `Bluefox*.zip`。
5. 通过 ADB 推送新包到手机 Download。
6. 推送成功后删除电脑端临时 zip，保持目录整洁。

## WebUI 使用说明

进入模块 WebUI 后，可以直接操作以下开关：

1. Backlog 4096
2. Awake 休眠锁
3. ZeroScan 零扫描
4. 代理接管
5. DNS 净化劫持
6. BBR 抢占模式
7. GPU 脱僵白名单

### GPU 白名单权限列表

1. 打开 `GPU 脱僵白名单 (防掉帧)` 开关。
2. 在 `GPU 白名单权限` 卡片中：
   - 搜索应用
   - 刷新应用列表
   - 直接勾选/取消勾选应用
3. 勾选变化会自动保存并立即生效，也可手动点一次“保存并立即生效”。

## GPU 策略说明

当满足以下条件时，脚本会激活高性能策略：

1. `enable_gpu_unlock` 已开启。
2. 当前前台应用在白名单中。

激活时：

1. 尝试关闭联发科 PPM 干预。
2. GPU governor 切换为 `performance`。
3. 最大频率写入 `900000000`（不追求极限超频）。

退出白名单应用后：

1. 恢复 governor 为 `dummy`。
2. 恢复 PPM。
3. 恢复上限到 `823000000`。

## 配置文件

运行时配置位于 `conf/`（由脚本自动创建）：

1. `enable_backlog`
2. `enable_awake`
3. `enable_zeroscan`
4. `enable_proxy`
5. `enable_dns`
6. `enable_bbr`
7. `enable_gpu_unlock`
8. `gpu_whitelist.txt`（每行一个应用 ID）

`gpu_whitelist.txt` 不存在时，会使用内置默认名单：

- `com.tencent.tmgp.roco`
- `com.tencent.tmgp.sgame`
- `com.miHoYo.Yuanshen`

## 注意事项

1. 本模块涉及网络栈、iptables、GPU 调度与温控策略，属于高权限改动。
2. 不同 ROM/内核实现有差异，部分节点可能不存在或不可写。
3. 若 WebUI 运行在非 KernelSU 环境，命令执行会失去特权上下文。
4. 若网络异常，建议先逐项关闭功能并回归默认，再定位具体开关。

## 开发约定

1. 实质性改动（功能、脚本、排障、关键配置变更）必须更新 `DEVLOG.md`。
2. 纯问答、纯原理讨论且没有实质变更时，不强制写日志。

## 免责声明

本项目按现状提供。使用者需自行承担在不同设备与系统版本上的兼容性风险，并在改动前做好数据备份。
