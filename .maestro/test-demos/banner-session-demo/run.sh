#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SANDBOX_DIR="$SCRIPT_DIR/sandbox"
mkdir -p "$SANDBOX_DIR"

rm -f "$SANDBOX_DIR"/*
cat > "$SANDBOX_DIR/banner_state.json" <<'JSON'
{
  "scenario": "disk_full",
  "bannerLevel": "error",
  "actionLabel": "打开存储设置",
  "message": "磁盘空间不足，无法继续整理。"
}
JSON

echo "已准备磁盘满 Banner 场景：$SANDBOX_DIR/banner_state.json"
