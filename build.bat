@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo =========================================
echo Biuld and Push - Bluefox_NX1_optimized
echo =========================================

REM 从 module.prop 提取版本号
for /f "tokens=2 delims==" %%a in ('findstr "^version=" module.prop') do (
    set RAW_VERSION=%%a
)

REM 替换掉版本号里面可能存在的空格（比如把 "v1.2" 变成 "v1.2_"，避免文件名截断）
set SAFE_VERSION=!RAW_VERSION: =_!
set ZIP_NAME=Bluefox_NX1_optimized_!SAFE_VERSION!.zip

echo 目标版本: !RAW_VERSION!
echo 输出文件: !ZIP_NAME!
echo.

echo [清理] 正在清理电脑端工作目录下的旧版本包...
del /Q *bluefox*.zip *Bluefox*.zip 2>nul

echo [打包] 正在将 核心文件 (module.prop, service.sh, action.sh, webroot) 压入压缩包...
REM 使用 Windows 10/11 自带的 tar.exe 命令直接进行 zip 压缩
tar.exe -a -c -f "!ZIP_NAME!" module.prop service.sh action.sh webroot

echo.
echo =========================================
echo 打包完成，临时文件已生成: !ZIP_NAME!
echo =========================================

echo.
echo [清理手机旧包] 正在清理手机 /sdcard/Download 目录下的所有历史版本旧包...
adb shell "rm -f /sdcard/Download/*Bluefox*.zip /sdcard/Download/*bluefox*.zip 2>/dev/null"

echo.
echo [ADB 推送] 正在尝试将新模块推送到手机 /sdcard/Download 目录...
adb push "!ZIP_NAME!" /sdcard/Download/
if !ERRORLEVEL! EQU 0 (
    echo [OK] 推送成功，手机 Download 目录中已保留最新包。
) else (
    echo [ERR] 推送失败，可能是手机未连接或未开启 USB 调试。
)

echo.
echo [收尾] 删除电脑端临时 zip，确保执行前后本地不留包...
del /Q "!ZIP_NAME!" 2>nul
echo [OK] 电脑端清理完成。

echo.
pause