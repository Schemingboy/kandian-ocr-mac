#!/bin/bash
# 看典古籍 OCR · Mac 一键安装脚本
# 用法：在「终端」里 cd 到本文件夹，然后运行：  ./install.sh
set -e
cd "$(dirname "$0")"

echo "== 1/3 检查 Python =="
if ! command -v python3 >/dev/null 2>&1; then
    echo "错误：没有检测到 Python 3.10-3.14。请先安装："
    echo "  1) 打开 https://www.python.org/downloads/ ，下载 macOS 版并安装"
    echo "  2) 装完后重新打开「终端」，再运行本脚本"
    exit 1
fi
PYTHON_VERSION="$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
if ! python3 -c 'import sys; raise SystemExit(0 if (3, 10) <= sys.version_info < (3, 15) else 1)'; then
    echo "错误：当前 Python ${PYTHON_VERSION}，本程序需要 Python 3.10-3.14（低于 3.15）。"
    echo "请从 https://www.python.org/downloads/ 安装新版 Python 后重试。"
    exit 1
fi
PYTHON_ARCH="$(python3 -c 'import platform; print(platform.machine())')"
echo "Python ${PYTHON_VERSION}，${PYTHON_ARCH} ✓"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "错误：本程序仅支持 macOS 13 或更高版本。"
    exit 1
fi
MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_MAJOR="${MACOS_VERSION%%.*}"
case "$MACOS_MAJOR" in
    ''|*[!0-9]*)
        echo "错误：无法确认 macOS 版本（检测结果：${MACOS_VERSION}）。"
        exit 1
        ;;
esac
if [ "$MACOS_MAJOR" -lt 13 ]; then
    echo "错误：当前 macOS ${MACOS_VERSION}，本程序需要 macOS 13 或更高版本。"
    echo "请先升级 macOS，再运行本脚本。"
    exit 1
fi
echo "macOS ${MACOS_VERSION} ✓"

echo ""
echo "== 2/3 创建独立运行环境 =="
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
VENV_PYTHON=".venv/bin/python"
if [ ! -x "$VENV_PYTHON" ]; then
    echo "错误：现有 .venv 不完整，找不到可运行的 .venv/bin/python。"
    echo "请删除当前仓库中的 .venv 文件夹，再重新运行 ./install.sh。"
    exit 1
fi
VENV_VERSION="$($VENV_PYTHON -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
if ! "$VENV_PYTHON" -c 'import sys; raise SystemExit(0 if (3, 10) <= sys.version_info < (3, 15) else 1)'; then
    echo "错误：现有 .venv 使用 Python ${VENV_VERSION}，需要 Python 3.10-3.14（低于 3.15）。"
    echo "请删除当前仓库中的 .venv 文件夹，再重新运行 ./install.sh。"
    exit 1
fi
VENV_ARCH="$($VENV_PYTHON -c 'import platform; print(platform.machine())')"
if [ "$PYTHON_ARCH" != "$VENV_ARCH" ]; then
    echo "错误：现有 .venv 架构为 ${VENV_ARCH}，当前 python3 架构为 ${PYTHON_ARCH}。"
    echo "请删除当前仓库中的 .venv 文件夹，再重新运行 ./install.sh。"
    exit 1
fi
echo ".venv：Python ${VENV_VERSION}，${VENV_ARCH} ✓"

echo ""
echo "== 3/3 安装依赖（首次需下载，约 1-2 分钟）=="
"$VENV_PYTHON" -m pip install --upgrade pip >/dev/null 2>&1 || true
"$VENV_PYTHON" -m pip install --quiet "PySide6>=6.10,<7" requests PyMuPDF python-docx

echo ""
echo "✅ 安装完成！"
echo "以后每次使用：双击 run.command 即可启动；"
echo "或在终端里运行：  ./.venv/bin/python kandian_ocr.py"
