#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_SCRIPT="$PROJECT_DIR/build_app.sh"
WORKFLOW="$PROJECT_DIR/.github/workflows/build-macos-app.yml"

grep -q -- '--windowed' "$BUILD_SCRIPT"
grep -q -- '--name "看典古籍OCR"' "$BUILD_SCRIPT"
grep -q -- 'codesign --verify --deep --strict' "$BUILD_SCRIPT"
grep -q -- 'QT_QPA_PLATFORM=offscreen' "$BUILD_SCRIPT"
grep -q -- 'macos-15' "$WORKFLOW"
grep -q -- 'macos-15-intel' "$WORKFLOW"
grep -q -- 'MACOSX_DEPLOYMENT_TARGET: "13.0"' "$WORKFLOW"
grep -q -- 'Kandian-OCR-macOS-${{ matrix.arch }}.zip' "$WORKFLOW"

echo "macOS app packaging checks: OK"
