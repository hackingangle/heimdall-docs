#!/usr/bin/env bash
# 仅检测本机 Harness 环境（不安装）。安装请直接运行 install-skills.sh。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/install-skills.sh" --detect
