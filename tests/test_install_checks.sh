#!/bin/bash
set -u

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

make_case() {
    CASE_DIR="$(mktemp -d)"
    cp "$PROJECT_DIR/install.sh" "$CASE_DIR/install.sh"
    chmod +x "$CASE_DIR/install.sh"
}

cleanup_case() {
    rm -rf "$CASE_DIR"
}

run_installer() {
    (
        export MOCK_SYSTEM_VERSION MOCK_SYSTEM_SUPPORTED MOCK_PYTHON_ARCH
        export MOCK_SYSTEM_NAME MOCK_MACOS_VERSION
        python3() {
            if [[ "$2" == *'print(".".join'* ]]; then
                echo "$MOCK_SYSTEM_VERSION"
                return 0
            fi
            if [[ "$2" == *"platform.machine"* ]]; then
                echo "$MOCK_PYTHON_ARCH"
                return 0
            fi
            [[ "$MOCK_SYSTEM_SUPPORTED" == "yes" ]]
        }
        uname() {
            echo "$MOCK_SYSTEM_NAME"
        }
        sw_vers() {
            echo "$MOCK_MACOS_VERSION"
        }
        export -f python3 uname sw_vers
        cd "$CASE_DIR"
        ./install.sh
    ) 2>&1
}

make_fake_venv() {
    mkdir -p "$CASE_DIR/.venv/bin"
    cp "$PROJECT_DIR/tests/venv_python_stub.sh" "$CASE_DIR/.venv/bin/python"
    chmod +x "$CASE_DIR/.venv/bin/python"
}

MOCK_SYSTEM_NAME="Darwin"
MOCK_PYTHON_ARCH="arm64"
MOCK_MACOS_VERSION="14.6.1"

make_case
MOCK_SYSTEM_VERSION="3.9.18"
MOCK_SYSTEM_SUPPORTED="no"
old_python_output="$(run_installer)" && fail "Python 3.9 should be rejected"
[[ "$old_python_output" == *"需要 Python 3.10-3.14"* ]] || fail "missing old Python error"
cleanup_case
echo "Python 3.9 guard: OK"

make_case
MOCK_SYSTEM_VERSION="3.15.0"
MOCK_SYSTEM_SUPPORTED="no"
new_python_output="$(run_installer)" && fail "Python 3.15 should be rejected"
[[ "$new_python_output" == *"低于 3.15"* ]] || fail "missing Python 3.15 error"
cleanup_case
echo "Python 3.15 guard: OK"

make_case
MOCK_SYSTEM_VERSION="3.11.9"
MOCK_SYSTEM_SUPPORTED="yes"
MOCK_MACOS_VERSION="12.7.6"
old_macos_output="$(run_installer)" && fail "macOS 12 should be rejected"
[[ "$old_macos_output" == *"需要 macOS 13 或更高版本"* ]] || fail "missing macOS version error"
cleanup_case
MOCK_MACOS_VERSION="14.6.1"
echo "macOS version guard: OK"

make_case
MOCK_SYSTEM_NAME="Linux"
non_macos_output="$(run_installer)" && fail "non-macOS platform should be rejected"
[[ "$non_macos_output" == *"仅支持 macOS 13 或更高版本"* ]] || fail "missing non-macOS error"
cleanup_case
MOCK_SYSTEM_NAME="Darwin"
echo "macOS platform guard: OK"

make_case
mkdir -p "$CASE_DIR/.venv"
broken_venv_output="$(run_installer)" && fail "incomplete venv should be rejected"
[[ "$broken_venv_output" == *"现有 .venv 不完整"* ]] || fail "missing incomplete venv error"
cleanup_case
echo "Incomplete venv guard: OK"

make_case
make_fake_venv
MOCK_VENV_VERSION="3.9.18"
MOCK_VENV_SUPPORTED="no"
MOCK_VENV_ARCH="arm64"
export MOCK_VENV_VERSION MOCK_VENV_SUPPORTED MOCK_VENV_ARCH
old_venv_output="$(run_installer)" && fail "old venv should be rejected"
[[ "$old_venv_output" == *"现有 .venv 使用 Python 3.9.18"* ]] || fail "missing old venv error"
cleanup_case
echo "Old venv guard: OK"

make_case
make_fake_venv
MOCK_VENV_VERSION="3.11.9"
MOCK_VENV_SUPPORTED="yes"
MOCK_VENV_ARCH="x86_64"
export MOCK_VENV_VERSION MOCK_VENV_SUPPORTED MOCK_VENV_ARCH
wrong_arch_output="$(run_installer)" && fail "wrong-architecture venv should be rejected"
[[ "$wrong_arch_output" == *"当前 python3 架构为 arm64"* ]] || fail "missing venv architecture error"
cleanup_case
echo "Venv architecture guard: OK"

make_case
make_fake_venv
MOCK_PYTHON_ARCH="x86_64"
MOCK_VENV_VERSION="3.11.9"
MOCK_VENV_SUPPORTED="yes"
MOCK_VENV_ARCH="x86_64"
export MOCK_VENV_VERSION MOCK_VENV_SUPPORTED MOCK_VENV_ARCH
rosetta_output="$(run_installer)" || fail "matching Intel Python and venv should work under Rosetta"
[[ "$rosetta_output" == *".venv：Python 3.11.9，x86_64"* ]] || fail "missing Rosetta-compatible venv success"
cleanup_case
MOCK_PYTHON_ARCH="arm64"
echo "Rosetta-compatible Intel Python/venv: OK"

[[ "$(<"$PROJECT_DIR/install.sh")" == *'"PySide6>=6.10,<7"'* ]] || fail "PySide6 compatibility range is missing"
echo "PySide6 compatibility range: OK"
