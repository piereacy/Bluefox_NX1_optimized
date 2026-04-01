#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import glob
import subprocess
import zipfile
from pathlib import Path

# 确保脚本始终在自己所在的目录运行，防止跨目录执行时找不到文件
os.chdir(os.path.dirname(os.path.abspath(__file__)))

INCLUDES = ['module.prop', 'service.sh', 'webroot']
PROJECT_NAME = "Bluefox_NX1_optimized"

def get_version():
    """解析 module.prop 提取 version="""
    try:
        with open('module.prop', 'r', encoding='utf-8') as f:
            for line in f:
                if line.startswith('version='):
                    return line.strip().split('=', 1)[1].strip()
    except FileNotFoundError:
        print("[!] 错误: 未找到 module.prop 文件")
        sys.exit(1)
    return "unknown"

def clean_local(pattern):
    """清理本地符合模式的文件"""
    for file in glob.glob(pattern):
        try:
            os.remove(file)
            print(f"  [-] 删除: {file}")
        except OSError as e:
            print(f"  [!] 删除失败 {file}: {e}")

def create_zip(zip_path):
    """打包核心文件到压缩包"""
    print(f"[打包] 正在将模块文件压入: {zip_path}")
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        for item in INCLUDES:
            p = Path(item)
            if not p.exists():
                print(f"  [!] 警告: 未找到 {item}，跳过该项")
                continue
            if p.is_file():
                zf.write(p, p)
            elif p.is_dir():
                for root, _, files in os.walk(p):
                    for file in files:
                        file_path = Path(root) / file
                        zf.write(file_path, file_path)

def adb_push(zip_path):
    """将压缩包推送到真机并清理真机旧包"""
    print("\n[清理手机旧包] 正在清理 /sdcard/Download 目录下的历史版本...")
    subprocess.run(['adb', 'shell', 'rm -f /sdcard/Download/*Bluefox*.zip /sdcard/Download/*bluefox*.zip 2>/dev/null'], capture_output=True)
    
    print(f"\n[ADB 推送] 正在推送到手机 /sdcard/Download 目录...")
    result = subprocess.run(['adb', 'push', str(zip_path), '/sdcard/Download/'])
    if result.returncode == 0:
        print("[OK] 推送成功！手机端已保留最新版本包。")
        return True
    else:
        print("[ERR] 推送失败！确保手机已连接并开启 USB 调试。")
        return False

def print_help():
    print("用法：")
    print("  python build.py push     # 打包，通过 ADB 推送至手机，并销毁电脑端的压缩包 (相当于原 build.bat)")
    print("  python build.py release  # 打包到 release/ 目录用于发布，不推送 (相当于原 build_release.bat)")
    print("  python build.py --help   # 显示此帮助并退出")

def main():
    mode = 'interactive'
    if len(sys.argv) > 1:
        arg = sys.argv[1].lower()
        if arg == 'push':
            mode = 'push'
        elif arg == 'release':
            mode = 'release'
        elif arg == 'pack':
            mode = 'pack_only'
        elif arg in ('-h', '--help', 'help'):
            print_help()
            sys.exit(0)
        else:
            print(f"[!] 未知参数: {sys.argv[1]}")
            print_help()
            sys.exit(1)

    print("=" * 45)
    print(f"  Build Script - {PROJECT_NAME}")
    print("=" * 45)

    if mode == 'interactive':
        print("\n请选择打包模式:")
        print("  1. 仅打包 (无 USB 调试，需手动传输给手机)")
        print("  2. 打包并推送给手机 (需要 USB 调试，推送目录为 /sdcard/Download/)")
        print("  3. 发布构建 (输出到 release/ 目录)")
        choice = input("\n请输入数字 (1/2/3) [默认选 1]: ").strip()
        if choice == '2':
            mode = 'push'
        elif choice == '3':
            mode = 'release'
        else:
            mode = 'pack_only'

    raw_version = get_version()
    safe_version = raw_version.replace(' ', '_')
    zip_name = f"{PROJECT_NAME}_{safe_version}.zip"

    if mode == 'release':
        out_dir = Path("release")
        out_dir.mkdir(exist_ok=True)
        out_zip = out_dir / zip_name
        
        print(f"\n模式: Release (发布)")
        print(f"版本: {raw_version}")
        print(f"输出: {out_zip}\n")
        
        print("[清理] 清理 release 目录旧包...")
        clean_local(str(out_dir / "*Bluefox*.zip"))
        clean_local(str(out_dir / "*bluefox*.zip"))

        create_zip(out_zip)
        print(f"\n[OK] 发布包已生成: {out_zip}")
        
    elif mode == 'push':
        print(f"\n模式: Push (编译并推送到手机)")
        print(f"版本: {raw_version}")
        print(f"临时输出: {zip_name}\n")
        
        print("[清理] 清理电脑工作区旧包...")
        clean_local("*Bluefox*.zip")
        clean_local("*bluefox*.zip")
        
        create_zip(zip_name)
        
        if adb_push(zip_name):
            print("\n[收尾] 删除电脑端临时 zip，保持工作区干净...")
            try:
                os.remove(zip_name)
                print("[OK] 本地清理完成。")
            except OSError as e:
                print(f"[!] 删除本地包失败: {e}")

    elif mode == 'pack_only':
        print(f"\n模式: 仅打包 (当前目录)")
        print(f"版本: {raw_version}")
        print(f"输出: {zip_name}\n")
        
        print("[清理] 清理电脑工作区旧包...")
        clean_local("*Bluefox*.zip")
        clean_local("*bluefox*.zip")
        
        create_zip(zip_name)
        print(f"\n[OK] 打包完成！请将当前文件夹下的 {zip_name} 手动拷贝到手机中安装。")

if __name__ == "__main__":
    try:
        main()
    finally:
        print("\n")
        if os.name == 'nt':
            print("按任意键退出...")
            os.system('pause >nul')
        else:
            input("按回车键退出...")
