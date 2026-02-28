#!/usr/bin/env bash
#
# PRD-Driven AI Team for Cursor
# Initialize a multi-agent development team in any Cursor project.
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/wirechen/PRD-Driven_AI_Team_For_Cursor/main/setup.sh)
#   or
#   git clone https://github.com/wirechen/PRD-Driven_AI_Team_For_Cursor.git && cd PRD-Driven_AI_Team_For_Cursor && bash setup.sh
#

set -euo pipefail

# ── Resolve script directory ────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If running via curl|bash, download the full repo first
if [ ! -f "$SCRIPT_DIR/lib/prompts.sh" ]; then
  echo "Downloading PRD-Driven AI Team..."
  TEMP_DIR=$(mktemp -d)
  git clone --depth 1 https://github.com/wirechen/PRD-Driven_AI_Team_For_Cursor.git "$TEMP_DIR" 2>/dev/null || {
    echo "Error: Failed to download. Please use: git clone https://github.com/wirechen/PRD-Driven_AI_Team_For_Cursor.git"
    exit 1
  }
  SCRIPT_DIR="$TEMP_DIR"
  CLEANUP_TEMP=true
else
  CLEANUP_TEMP=false
fi

# ── Source modules ──────────────────────────────────────────────────
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/prompts.sh"
source "$SCRIPT_DIR/lib/generator.sh"

# ── Banner ──────────────────────────────────────────────────────────
clear
echo ""
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'
  ╔═══════════════════════════════════════════════════════════╗
  ║                                                           ║
  ║   PRD-Driven AI Team for Cursor                           ║
  ║                                                           ║
  ║   通过 PRD 驱动 AI 团队并行开发 Web 应用                  ║
  ║   维护 PRD 即可推进项目，无需关心代码细节                  ║
  ║                                                           ║
  ╚═══════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"
echo -e "  ${DIM}方法论：代码服从 PRD，PRD 服从用户${NC}"
echo -e "  ${DIM}GitHub: https://github.com/wirechen/PRD-Driven_AI_Team_For_Cursor${NC}"
echo ""

# ── Run interactive prompts ─────────────────────────────────────────
run_prompts

# ── Generate files ──────────────────────────────────────────────────
generate_files

# ── Cleanup temp dir if downloaded via curl ─────────────────────────
if [ "$CLEANUP_TEMP" = true ] && [ -n "${TEMP_DIR:-}" ]; then
  rm -rf "$TEMP_DIR"
fi
