#!/bin/bash
# 看典古籍 OCR · Mac 启动器（在 Finder 里双击即可启动）
cd "$(dirname "$0")"
if [ ! -d ".venv" ]; then
    echo "还没安装依赖。请先运行 install.sh（见 README.md）。"
    read -n 1 -s -r -p "按任意键退出…"
    exit 1
fi
exec ./.venv/bin/python kandian_ocr.py
