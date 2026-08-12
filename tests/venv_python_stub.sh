#!/bin/bash
if [[ "${1:-}" == "-c" && "${2:-}" == *'print(".".join'* ]]; then
    echo "$MOCK_VENV_VERSION"
    exit 0
fi
if [[ "${1:-}" == "-c" && "${2:-}" == *"sys.version_info"* ]]; then
    [[ "$MOCK_VENV_SUPPORTED" == "yes" ]]
    exit
fi
if [[ "${1:-}" == "-c" && "${2:-}" == *"platform.machine"* ]]; then
    echo "$MOCK_VENV_ARCH"
    exit 0
fi
if [[ "${1:-}" == "-m" && "${2:-}" == "pip" ]]; then
    exit 0
fi
exit 1
