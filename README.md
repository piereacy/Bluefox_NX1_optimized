# Bluefox_NX1_optimized

## 项目声明

1. 本项目主要由 AI 参与生成，属于 vibe coding 产物。
2. 本项目不参与任何商业行为，不提供商业授权与商业支持。
3. 允许二次开发与分发，但请自行承担兼容性与使用风险。
4. 项目代码含金量不高，更适合学习和折腾用途。

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
7. GPU 脱僵白名单与权限管理
   - 在 WebUI 勾选应用即可加入白名单，仅对白名单应用激活高性能 GPU 策略，日常自动回到省电策略。

## 项目结构

```text
Bluefox_NX1_optimized/
  service.sh          # 核心守护脚本（每 30 秒轮询并应用策略）
  module.prop         # 模块元数据
  build.py            # 跨平台构建与推送脚本 (取代原有的 bat)
  webroot/
    index.html        # WebUI 前端
```

## 环境要求

1. Android 设备，已获取 root。
2. 已安装 KernelSU，且支持模块 WebUI。
3. 设备具备基础命令能力：`sh`、`pm`、`settings`、`iptables`、`dumpsys`。        
4. 电脑端需要安装 Python 3 环境，构建与推送需要可用的 `adb`。

## 安装与使用

### 方式 A：KernelSU 管理器直接刷入

1. 从本仓库的 Releases 页面下载编译好的模块 zip 压缩包。
2. 在 KernelSU 管理器中安装该 zip 模块。
3. 重启设备。
4. 进入模块的 WebUI 页面进行开关配置。

### 方式 B：使用 Python 脚本构建与推送（build.py）

`build.py` 执行流程（支持全平台）：

- 提供交互式菜单，可以选择：
  1. 仅打包 Release 到电脑 `release/` 目录。
  2. 收拾并推送到手机 `/sdcard/Download` 下并自动覆盖旧包。
- 自动读取 `module.prop` 版本号作为压缩包名称。
- 自动忽略不需要的开发日志和隐藏文件夹。

1. Backlog 4096
2. Awake 休眠锁
3. ZeroScan 零扫描
4. 代理接管
5. DNS 净化劫持
6. BBR 抢占模式
7. GPU 脱僵白名单 (防掉帧)

在 GPU 模块内：能够搜索应用、刷新列表、直接勾选/取消勾选白名单应用。每一次勾选变化会自动保存并立即生效，也可手动点一次“保存白名单并立即生效”。

## GPU 策略说明

当满足以下条件时，脚本会激活高性能策略：

1. `enable_gpu_unlock` 已开启。
2. 当前前台应用在白名单中。

激活时：

1. 尝试关闭联发科 PPM 干预。
2. GPU governor 切换为 `performance`。
3. 最大频率写入 `900 MHz`（不追求极限超频）。

退出白名单应用后：

1. 恢复 governor 为 `dummy`。
2. 恢复 PPM。
3. 恢复上限到 `823 MHz`。

## 配置文件

运行时配置位于 `/data/adb/Bluefox_NX1_optimized_conf/`（由脚本自动在外挂目录创建以保活数据）：

1. `enable_backlog`
2. `enable_awake`
3. `enable_zeroscan`
4. `enable_proxy`
5. `enable_dns`
6. `enable_bbr`
7. `enable_gpu_unlock`
8. `gpu_whitelist.txt`（每行一个应用 ID）

`gpu_whitelist.txt` 不存在时，会使用空名单，模块首次使用时请务必进入 WebUI 中手动勾选相关应用。

## 注意事项

1. 本模块涉及网络栈、iptables、GPU 调度与温控策略，属于高权限改动。
2. 不同 ROM/内核实现有差异，部分节点可能不存在或不可写。
3. 若 WebUI 运行在非 KernelSU 环境，命令执行会失去特权上下文。
4. 若网络异常，建议先逐项关闭功能并回归默认，再定位具体开关。

## 免责声明

本项目按现状提供。使用者需自行承担在不同设备与系统版本上的兼容性风险，并在改动前做好数据备份。
