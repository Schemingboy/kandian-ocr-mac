#!/bin/bash
# 在 macOS 上生成可双击运行的看典古籍 OCR.app。
set -euo pipefail
cd "$(dirname "$0")"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "错误：客户端只能在 macOS 上打包。"
    exit 1
fi

PYTHON_BIN="${PYTHON_BIN:-python3}"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    echo "错误：找不到 ${PYTHON_BIN}。"
    exit 1
fi

echo "== 1/4 安装打包依赖 =="
"$PYTHON_BIN" -m pip install --quiet \
    "PySide6>=6.10,<7" requests PyMuPDF python-docx "pyinstaller>=6.16,<7"

echo "== 2/4 运行自动检查 =="
"$PYTHON_BIN" -m unittest discover -s tests -v

echo "== 3/4 生成看典古籍OCR.app =="
"$PYTHON_BIN" -m PyInstaller \
    --noconfirm \
    --clean \
    --windowed \
    --name "看典古籍OCR" \
    --osx-bundle-identifier "com.kandianguji.ocr" \
    --hidden-import fitz \
    --hidden-import docx \
    --hidden-import requests \
    kandian_ocr.py

APP_PATH="dist/看典古籍OCR.app"
if [ ! -x "$APP_PATH/Contents/MacOS/看典古籍OCR" ]; then
    echo "错误：没有生成可运行的客户端。"
    exit 1
fi

# 临时签名可保证应用包结构完整；首次下载后仍可能需要右键选择“打开”。
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

echo "== 4/4 启动检查 =="
QT_QPA_PLATFORM=offscreen "$APP_PATH/Contents/MacOS/看典古籍OCR" &
APP_PID=$!
sleep 5
if ! kill -0 "$APP_PID" 2>/dev/null; then
    wait "$APP_PID"
    echo "错误：客户端启动后立即退出。"
    exit 1
fi
kill "$APP_PID"
wait "$APP_PID" 2>/dev/null || true

echo "完成：$APP_PATH"
