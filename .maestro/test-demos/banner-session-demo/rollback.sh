#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SANDBOX_DIR="$SCRIPT_DIR/sandbox"
mkdir -p "$SANDBOX_DIR"

rm -f "$SANDBOX_DIR"/*
cat > "$SANDBOX_DIR/banner_state.json" <<'JSON'
{
  "scenario": "trash_partial_fail",
  "bannerLevel": "warning",
  "actionLabel": "",
  "message": "部分文件未能移入废纸篓，请检查权限或稍后再试。"
}
JSON

echo "已准备 Trash 部分失败 Banner 场景：$SANDBOX_DIR/banner_state.json"
