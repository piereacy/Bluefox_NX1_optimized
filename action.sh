#!/system/bin/sh

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 正在拉起 WebUI 图形化控制面板..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 获取 KernelSU 为该模块生成的 WebUI 链接
# KernelSU 的模块 webroot 访问路径通常为：
# http://127.0.0.1:xxx/modules/bluefox_wifi_optimizer/

# 注意：KernelSU 较新版本会自动处理这个内部端口，如果我们要在 Android 发起系统级页面拉取
# 需要使用 am start 命令拉起外部浏览器 或 KSU Manager 的 DeepLink。

# 这里使用一种通用技巧：
# 假如用户点击了此按钮，我们利用 intent 告诉用户，请直接前往 KernelSU 的 Web 界面
# 因为直接拉外部浏览器(比如 Chrome) 打开 127.0.0.1 的 KSU内嵌网页会面临鉴权失败被拦截的风险
# (因为外部浏览器没有 window.ksu.exec 上下文)

echo ""
echo "[✔️] 本模块支持极致的 Material Design 网页图形化界面！"
echo ""
echo "请不要在这里敲击终端了！"
echo "👉 请点击 KernelSU 模块管理页面里，本模块右下角的【设置 / WebUI】图标进入控制面板。"
echo "👉 如果你没有看到设置图标，请确保你的 KernelSU 管理器版本是最新的。"
echo ""
echo "由于模块执行依赖强大的底层权限，系统限制了从第三方普通应用强制跳转至特权页面。"
echo "请手动点击本页面的 WebUI 入口。"
echo ""

sleep 3
exit 0