#!/bin/bash
# 看典古籍 OCR · Mac 一键安装脚本
# 用法：在「终端」里 cd 到本文件夹，然后运行：  ./install.sh
set -e
cd "$(dirname "$0")"

echo "== 1/3 检查 Python =="
if ! command -v python3 >/dev/null 2>&1; then
    echo "没有检测到 Python3。请先安装："
    echo "  1) 打开 https://www.python.org/downloads/ ，下载 macOS 版并安装"
    echo "  2) 安装界面务必勾选 “Add Python to PATH”"
    echo "  3) 装完后重新打开「终端」，再运行本脚本"
    exit 1
fi
python3 -c 'import sys; print("Python", sys.version.split()[0], "✓")'

echo ""
echo "== 2/3 创建独立运行环境 =="
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate

echo ""
echo "== 3/3 安装依赖（首次需下载，约 1-2 分钟）=="
python -m pip install --upgrade pip >/dev/null 2>&1 || true
pip install --quiet PySide6 requests PyMuPDF python-docx

echo ""
echo "✅ 安装完成！"
echo "以后每次使用：双击 run.command 即可启动；"
echo "或在终端里运行：  ./.venv/bin/python kandian_ocr.py"
