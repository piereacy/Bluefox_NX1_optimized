#!/system/bin/sh
MODDIR=${0%/*}
CONF_DIR="$MODDIR/conf"
GPU_WHITELIST_FILE="$CONF_DIR/gpu_whitelist.txt"
DEFAULT_GPU_WHITELIST="com.tencent.tmgp.roco com.tencent.tmgp.sgame com.miHoYo.Yuanshen"

# 确保配置目录存在 (用于WebUI和内核脚本的文件通信)
mkdir -p "$CONF_DIR"

# 等待系统完全启动
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done

# ==========================================
# 核心功能控制函数
# ==========================================

# 1. Backlog 4096 (TCP/网络并发队列优化，缓解中继时的连接阻塞)
apply_backlog() {
    if [ -f "$CONF_DIR/enable_backlog" ]; then
        echo 4096 > /proc/sys/net/ipv4/tcp_max_syn_backlog 2>/dev/null
        echo 4096 > /proc/sys/net/core/somaxconn 2>/dev/null
        echo 4096 > /proc/sys/net/core/netdev_max_backlog 2>/dev/null
    else
        # 恢复默认（通常是 128 或 1024，视内核而定，这里回退较保守的值）
        echo 1024 > /proc/sys/net/ipv4/tcp_max_syn_backlog 2>/dev/null
        echo 1024 > /proc/sys/net/core/somaxconn 2>/dev/null
        echo 1000 > /proc/sys/net/core/netdev_max_backlog 2>/dev/null
    fi
}

# 2. Awake (强制休眠锁，防止息屏断流)
apply_awake() {
    if [ -f "$CONF_DIR/enable_awake" ]; then
        # 写入内核休眠锁
        echo "bluefox_wifi_awake" > /sys/power/wake_lock 2>/dev/null
    else
        # 释放休眠锁
        echo "bluefox_wifi_awake" > /sys/power/wake_unlock 2>/dev/null
    fi
}

# 3. ZeroScan (关闭所有后台 Wi-Fi 扫描，防止跳 Ping)
apply_zeroscan() {
    if [ -f "$CONF_DIR/enable_zeroscan" ]; then
        # 关闭全局 Wi-Fi 总是扫描（位置服务）
        settings put global wifi_scan_always_enabled 0 2>/dev/null
        # 尝试通过 cmd wifi 接口禁用扫描
        cmd wifi set-scan-always-available false >/dev/null 2>&1
    else
        settings put global wifi_scan_always_enabled 1 2>/dev/null
        cmd wifi set-scan-always-available true >/dev/null 2>&1
    fi
}

# 4. 代理接管 (Tethering VPN/Proxy Takeover)
# 将热点设备(比如 ap0 或 wlan1) 的流量全部转发到本机 VPN 接口 (如 tun0)
apply_proxy_takeover() {
    # 清理旧规则 (防止重复添加)
    iptables -t nat -D POSTROUTING -o tun+ -j MASQUERADE 2>/dev/null
    iptables -D FORWARD -i tun+ -o wlan+ -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
    iptables -D FORWARD -i wlan+ -o tun+ -j ACCEPT 2>/dev/null
    iptables -D FORWARD -i tun+ -o ap+ -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
    iptables -D FORWARD -i ap+ -o tun+ -j ACCEPT 2>/dev/null

    if [ -f "$CONF_DIR/enable_proxy" ]; then
        # 开启系统的 IP 转发
        echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null
        
        # 将热点接口 (wlanX / apX) 流量转发至 VPN (tunX)
        iptables -t nat -A POSTROUTING -o tun+ -j MASQUERADE
        # 针对 Wi-Fi to Wi-Fi 的中继接口通常是 wlan1 或 wlan2
        iptables -I FORWARD -i tun+ -o wlan+ -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables -I FORWARD -i wlan+ -o tun+ -j ACCEPT
        # 针对传统开热点的接口 ap0
        iptables -I FORWARD -i tun+ -o ap+ -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables -I FORWARD -i ap+ -o tun+ -j ACCEPT
    fi
}

# 5. TCP 拥塞控制算法动态切换 (BBR / Cubic)
apply_tcp_algo() {
    if [ -f "$CONF_DIR/enable_bbr" ]; then
        echo "bbr" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
    else
        echo "cubic" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
    fi
}

# 6. DNS 净化与劫持防污染 (劫持热点发出的 53 端口到阿里 DNS)
apply_dns_purify() {
    # 无论如何先清除旧规则防止重复叠加
    iptables -t nat -D PREROUTING -p udp --dport 53 -j DNAT --to-destination 223.5.5.5:53 2>/dev/null
    iptables -t nat -D PREROUTING -p tcp --dport 53 -j DNAT --to-destination 223.5.5.5:53 2>/dev/null

    if [ -f "$CONF_DIR/enable_dns" ]; then
        iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to-destination 223.5.5.5:53 2>/dev/null
        iptables -t nat -A PREROUTING -p tcp --dport 53 -j DNAT --to-destination 223.5.5.5:53 2>/dev/null
    fi
}

# 7. AP Watchdog 热点进程崩溃自愈狗 (静默执行)
ap_watchdog() {
    # 如果监测到 ap0/wlan1 (常见热点虚拟接口) 状态进入异常挂起
    # 此处利用 `cmd tethering` API 强制重新激活 Wi-Fi tethering
    # 为了防止干扰用户自己手动关闭的情况，只在检测到内核 crash 或软硬件不一致时起效。
    # 这里用一种轻量的检测作为预留占位：如果 wlan1 接口还在，但状态变成了 DOWN，拉起它。
    if ip link show wlan1 2>/dev/null | grep -q "state DOWN"; then
        ip link set wlan1 up 2>/dev/null
    fi
}

# 判断当前前台应用是否在 GPU 白名单
is_gpu_whitelisted() {
    local pkg="$1"
    [ -z "$pkg" ] && return 1

    if [ -f "$GPU_WHITELIST_FILE" ]; then
        grep -Fxq "$pkg" "$GPU_WHITELIST_FILE" 2>/dev/null
        return $?
    fi

    for item in $DEFAULT_GPU_WHITELIST; do
        [ "$pkg" = "$item" ] && return 0
    done
    return 1
}

# 8. 游戏性能白名单 (GPU Dummy 剔除与平滑释放)
apply_gpu_unlock() {
    local devfreq_gov="/sys/class/devfreq/13040000.mali/governor"
    local devfreq_max="/sys/class/devfreq/13040000.mali/max_freq"

    # 在某些旧版内核，路径可能在固定platform下
    if [ ! -f "$devfreq_gov" ] && [ -f "/sys/devices/platform/13040000.mali/devfreq/13040000.mali/governor" ]; then
        devfreq_gov="/sys/devices/platform/13040000.mali/devfreq/13040000.mali/governor"
        devfreq_max="/sys/devices/platform/13040000.mali/devfreq/13040000.mali/max_freq"
    fi

    # 查阅是否激活了性能解锁白名单
    if [ -f "$CONF_DIR/enable_gpu_unlock" ]; then
        # 读取当前运行的最顶层包名 (dumpsys window | grep mCurrentFocus)
        local top_app=$(dumpsys window | grep mCurrentFocus | awk -F'/' '{print $1}' | awk -F' ' '{print $NF}')
        
        # 使用配置文件白名单（不存在时回退到内置默认名单）
        if is_gpu_whitelisted "$top_app"; then
            # 如果当前是傀儡调度，则替换并强开 PPM 温控拦截
            local cur_gov=$(cat "$devfreq_gov" 2>/dev/null)
            if [ "$cur_gov" = "dummy" ] || [ "$cur_gov" != "performance" ]; then
                # 关闭联发科的 PPM, 防止其强行微调锁频
                if [ -d "/proc/ppm" ]; then
                    echo 0 > /proc/ppm/enabled 2>/dev/null
                fi
                # 将调度器切为系统的动态高性能调度 或者直接上 performance (为了安全不超频，仅去除屏蔽)
                echo "performance" > "$devfreq_gov" 2>/dev/null
                # 为了安全，仍然将最大频率墙写定到甜点 900MHz，防止硬件 PMIC 崩溃
                echo 900000000 > "$devfreq_max" 2>/dev/null
            fi
        else
            # 游戏切入后台或退出，即刻自愈（恢复到自带的省电木偶调度和PPM监听）
            local cur_gov_restore=$(cat "$devfreq_gov" 2>/dev/null)
            if [ "$cur_gov_restore" != "dummy" ] && [ "$cur_gov_restore" != "" ]; then
                echo "dummy" > "$devfreq_gov" 2>/dev/null
                echo 1 > /proc/ppm/enabled 2>/dev/null
                # 恢复原生频率锁墙 823M (或默认最高)
                echo 823000000 > "$devfreq_max" 2>/dev/null
            fi
        fi
    else
        # 并未开启此卡片功能，维持默认的保护状态
        local cur_gov_off=$(cat "$devfreq_gov" 2>/dev/null)
        if [ "$cur_gov_off" = "performance" ]; then
            echo "dummy" > "$devfreq_gov" 2>/dev/null
            echo 1 > /proc/ppm/enabled 2>/dev/null
        fi
    fi
}

# ==========================================
# 状态监听与主循环
# ==========================================

# 支持通过命令行参数手动更新配置
if [ "$1" = "update" ]; then
    apply_backlog
    apply_awake
    apply_zeroscan
    apply_proxy_takeover
    apply_tcp_algo
    apply_dns_purify
    apply_gpu_unlock
    exit 0
fi

# 初始化执行一次
apply_backlog
apply_awake
apply_zeroscan
apply_proxy_takeover
apply_tcp_algo
apply_dns_purify
apply_gpu_unlock


# 定期循环检测配置状态变化并应用
while true; do
    apply_backlog
    apply_awake
    apply_zeroscan
    apply_proxy_takeover
    apply_tcp_algo
    apply_dns_purify
    ap_watchdog
    apply_gpu_unlock
    sleep 30
done