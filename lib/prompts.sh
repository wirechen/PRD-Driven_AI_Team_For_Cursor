#!/usr/bin/env bash
# Interactive prompt flow — 7 steps

_PROMPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_PROMPTS_DIR/utils.sh"

# ── Global config variables (populated by prompts) ──────────────────
PROJECT_NAME=""
PROJECT_DESC=""
PROJECT_DIR=""
PLATFORMS=""          # pipe-separated: PC Web|微信小程序
TECH_MODE=""          # recommend / custom
TECH_FRONTEND=""
TECH_MINIAPP=""
TECH_BACKEND=""
TECH_DB=""
TECH_EXTRA=""
TEAM_MEMBERS=""       # pipe-separated: 产品经理|前端开发工程师|...
CUSTOM_ROLES=""       # pipe-separated custom role entries
MODEL_MODE=""         # recommend / custom
# Model storage: using parallel arrays instead of associative arrays for bash 3 compat
AGENT_MODEL_KEYS=""   # pipe-separated member names
AGENT_MODEL_VALS=""   # pipe-separated model names
PRD_MODE=""           # skeleton / example / skip
HAS_FRONTEND=false
HAS_MINIAPP=false
HAS_BACKEND_ONLY=false

# ── Model storage helpers (bash 3 compatible) ───────────────────────
set_agent_model() {
  local member=$1 model=$2
  if [ -z "$AGENT_MODEL_KEYS" ]; then
    AGENT_MODEL_KEYS="$member"
    AGENT_MODEL_VALS="$model"
  else
    AGENT_MODEL_KEYS="$AGENT_MODEL_KEYS|$member"
    AGENT_MODEL_VALS="$AGENT_MODEL_VALS|$model"
  fi
}

get_agent_model() {
  local member=$1
  local IFS='|'
  local -a keys=($AGENT_MODEL_KEYS)
  local -a vals=($AGENT_MODEL_VALS)
  for i in "${!keys[@]}"; do
    if [ "${keys[$i]}" = "$member" ]; then
      echo "${vals[$i]}"
      return
    fi
  done
  echo "claude-sonnet-4"
}

# ════════════════════════════════════════════════════════════════════
#  Step 1: Project basics
# ════════════════════════════════════════════════════════════════════
step_project_info() {
  print_step 1 7 "项目基本信息"

  ask_input "项目名称（英文，用于目录名）" "my-app" PROJECT_NAME

  ask_input "项目一句话描述" "" PROJECT_DESC

  # Default location: parent of current script directory / project name
  local default_parent
  default_parent="$(cd "$(pwd)/.." 2>/dev/null && pwd || pwd)"
  local default_path="$default_parent/$PROJECT_NAME"

  ask_select "项目初始化位置" "$default_path|指定其他路径" _loc_choice 0
  if [[ "$_loc_choice" == *"指定"* ]]; then
    ask_input "请输入目标路径" "$default_path" PROJECT_DIR
    if [ "$(basename "$PROJECT_DIR")" != "$PROJECT_NAME" ]; then
      PROJECT_DIR="$PROJECT_DIR/$PROJECT_NAME"
    fi
  else
    PROJECT_DIR="$default_path"
  fi

  print_success "项目: ${BOLD}$PROJECT_NAME${NC}"
  print_info "路径: $PROJECT_DIR"
}

# ════════════════════════════════════════════════════════════════════
#  Step 2: Platform type
# ════════════════════════════════════════════════════════════════════
step_platform() {
  print_step 2 7 "平台类型"

  ask_multiselect "你的项目需要支持哪些平台？" \
    "PC Web（浏览器端）|H5 移动端|微信小程序|仅后端 API（无前端）" \
    "1,1,0,0" \
    PLATFORMS

  # Parse selections
  HAS_FRONTEND=false
  HAS_MINIAPP=false
  HAS_BACKEND_ONLY=false

  if [[ "$PLATFORMS" == *"PC Web"* ]] || [[ "$PLATFORMS" == *"H5"* ]]; then
    HAS_FRONTEND=true
  fi
  if [[ "$PLATFORMS" == *"小程序"* ]]; then
    HAS_MINIAPP=true
  fi
  if [[ "$PLATFORMS" == *"仅后端"* ]]; then
    HAS_BACKEND_ONLY=true
    HAS_FRONTEND=false
    HAS_MINIAPP=false
  fi

  # Miniapp friendly warning
  if [ "$HAS_MINIAPP" = true ]; then
    echo ""
    print_warning "微信小程序开发需要安装「微信开发者工具」。"
    print_info "如果你没有开发背景，建议选择 H5 移动端作为替代，"
    print_info "同样可以在手机上使用，且无需额外工具。"
    if ! ask_confirm "是否继续选择微信小程序？"; then
      PLATFORMS=$(echo "$PLATFORMS" | sed 's/|*微信小程序|*/|/g; s/^|//; s/|$//')
      HAS_MINIAPP=false
      if [[ "$PLATFORMS" != *"H5"* ]] && [[ "$PLATFORMS" != *"PC Web"* ]]; then
        PLATFORMS="H5 移动端${PLATFORMS:+|$PLATFORMS}"
        HAS_FRONTEND=true
      fi
      print_success "已将微信小程序替换为 H5 移动端"
    fi
  fi

  print_success "已选平台: ${BOLD}$PLATFORMS${NC}"
}

# ════════════════════════════════════════════════════════════════════
#  Step 3: Tech stack
# ════════════════════════════════════════════════════════════════════
step_tech_stack() {
  print_step 3 7 "技术栈配置"

  ask_select "你希望如何配置技术栈？" \
    "一键推荐（适合新手，回车即可）|我要自己选择" \
    TECH_MODE

  if [[ "$TECH_MODE" == *"推荐"* ]]; then
    TECH_MODE="recommend"
    # Auto-recommend based on platform
    if [ "$HAS_FRONTEND" = true ]; then
      TECH_FRONTEND="React + TypeScript + Ant Design"
    fi
    if [ "$HAS_MINIAPP" = true ]; then
      TECH_MINIAPP="微信原生小程序"
    fi
    TECH_BACKEND="Python + FastAPI + SQLAlchemy"
    TECH_DB="MySQL"
    TECH_EXTRA=""

    echo ""
    print_info "已为你选择以下技术栈："
    [ "$HAS_FRONTEND" = true ] && print_success "前端: $TECH_FRONTEND"
    [ "$HAS_MINIAPP" = true ] && print_success "小程序: $TECH_MINIAPP"
    print_success "后端: $TECH_BACKEND"
    print_success "数据库: $TECH_DB"
  else
    TECH_MODE="custom"

    if [ "$HAS_FRONTEND" = true ]; then
      ask_input "前端框架" "React + TypeScript + Ant Design" TECH_FRONTEND
    fi
    if [ "$HAS_MINIAPP" = true ]; then
      echo ""
      print_info "可选：微信原生小程序 / uni-app / Taro"
      ask_input "小程序开发框架" "微信原生小程序" TECH_MINIAPP
    fi
    ask_input "后端框架" "Python + FastAPI + SQLAlchemy" TECH_BACKEND
    ask_input "数据库" "MySQL" TECH_DB
    ask_input "其他依赖（可选，直接回车跳过）" "" TECH_EXTRA
  fi
}

# ── Environment detection & install ─────────────────────────────────
step_env_check() {
  echo ""
  print_info "正在检测开发环境..."

  local missing=()
  local install_cmds=()
  local os_type
  os_type="$(uname -s)"

  # Detect Node.js (needed for frontend)
  if [ "$HAS_FRONTEND" = true ] || [ "$HAS_MINIAPP" = true ]; then
    if command -v node &>/dev/null; then
      print_success "Node.js $(node -v) — 已安装"
    else
      print_error "Node.js — 未安装"
      missing+=("Node.js")
      if [ "$os_type" = "Darwin" ]; then
        install_cmds+=("brew install node")
      else
        install_cmds+=("curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs")
      fi
    fi
  fi

  # Detect Python (if backend uses Python)
  if [[ "$TECH_BACKEND" == *"Python"* ]] || [[ "$TECH_BACKEND" == *"FastAPI"* ]] || [[ "$TECH_BACKEND" == *"Django"* ]] || [[ "$TECH_BACKEND" == *"Flask"* ]]; then
    if command -v python3 &>/dev/null; then
      print_success "Python $(python3 --version 2>&1 | awk '{print $2}') — 已安装"
    else
      print_error "Python 3 — 未安装"
      missing+=("Python")
      if [ "$os_type" = "Darwin" ]; then
        install_cmds+=("brew install python3")
      else
        install_cmds+=("sudo apt-get install -y python3 python3-pip python3-venv")
      fi
    fi
  fi

  # Detect MySQL (if using MySQL)
  if [[ "$TECH_DB" == *"MySQL"* ]] || [[ "$TECH_DB" == *"mysql"* ]]; then
    if command -v mysql &>/dev/null; then
      print_success "MySQL $(mysql --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) — 已安装"
    else
      print_error "MySQL — 未安装"
      missing+=("MySQL")
      if [ "$os_type" = "Darwin" ]; then
        install_cmds+=("brew install mysql && brew services start mysql")
      else
        install_cmds+=("sudo apt-get install -y mysql-server && sudo systemctl start mysql")
      fi
    fi
  fi

  # Detect PostgreSQL
  if [[ "$TECH_DB" == *"PostgreSQL"* ]] || [[ "$TECH_DB" == *"postgres"* ]]; then
    if command -v psql &>/dev/null; then
      print_success "PostgreSQL $(psql --version 2>&1 | awk '{print $3}') — 已安装"
    else
      print_error "PostgreSQL — 未安装"
      missing+=("PostgreSQL")
      if [ "$os_type" = "Darwin" ]; then
        install_cmds+=("brew install postgresql && brew services start postgresql")
      else
        install_cmds+=("sudo apt-get install -y postgresql && sudo systemctl start postgresql")
      fi
    fi
  fi

  # Check if brew is available on macOS
  if [ "$os_type" = "Darwin" ] && [ ${#missing[@]} -gt 0 ]; then
    if ! command -v brew &>/dev/null; then
      print_warning "macOS 上需要 Homebrew 来安装依赖"
      if ask_confirm "是否先安装 Homebrew？"; then
        echo -e "  ${DIM}正在安装 Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      else
        print_warning "请手动安装缺少的依赖后重新运行脚本"
        return 0
      fi
    fi
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    echo ""
    print_warning "检测到缺少以下依赖: ${missing[*]}"
    if ask_confirm "是否自动安装？（可能需要几分钟）"; then
      for cmd in "${install_cmds[@]}"; do
        echo -e "  ${DIM}执行: $cmd${NC}"
        eval "$cmd"
        if [ $? -eq 0 ]; then
          print_success "安装成功"
        else
          print_error "安装失败，请手动执行: $cmd"
        fi
      done
    else
      print_info "跳过自动安装，请手动安装后继续使用"
    fi
  else
    print_success "所有依赖已就绪"
  fi
}

# ════════════════════════════════════════════════════════════════════
#  Step 4: Team configuration
# ════════════════════════════════════════════════════════════════════
step_team() {
  print_step 4 7 "团队配置"

  local opts=""
  local defaults=""

  if [ "$HAS_FRONTEND" = true ] || [ "$HAS_MINIAPP" = true ]; then
    opts="前端开发工程师"
    defaults="r"
  fi

  opts="${opts:+$opts|}后端开发工程师"
  defaults="${defaults:+$defaults,}r"

  opts="$opts|产品经理"
  defaults="$defaults,1"

  opts="$opts|测试工程师"
  defaults="$defaults,1"

  opts="$opts|添加自定义角色..."
  defaults="$defaults,0"

  ask_multiselect "选择你的 AI 团队成员" "$opts" "$defaults" TEAM_MEMBERS

  # Handle custom roles
  if [[ "$TEAM_MEMBERS" == *"自定义"* ]]; then
    TEAM_MEMBERS=$(echo "$TEAM_MEMBERS" | sed 's/|*添加自定义角色\.\.\.|*/|/g; s/^|//; s/|$//')
    CUSTOM_ROLES=""
    while true; do
      local role_name role_desc
      ask_input "自定义角色名称（英文，如 devops-agent）" "" role_name
      if [ -z "$role_name" ]; then
        break
      fi
      ask_input "角色描述（一句话）" "" role_desc
      TEAM_MEMBERS="$TEAM_MEMBERS|$role_desc"
      CUSTOM_ROLES="${CUSTOM_ROLES:+$CUSTOM_ROLES|}$role_name:$role_desc"
      if ! ask_confirm "继续添加自定义角色？" "n"; then
        break
      fi
    done
  else
    # Remove "添加自定义角色..." if not selected
    TEAM_MEMBERS=$(echo "$TEAM_MEMBERS" | sed 's/|*添加自定义角色\.\.\.|*/|/g; s/^|//; s/|$//')
  fi

  print_success "团队成员: ${BOLD}$TEAM_MEMBERS${NC}"
}

# ════════════════════════════════════════════════════════════════════
#  Step 5: Model selection
# ════════════════════════════════════════════════════════════════════
step_models() {
  print_step 5 7 "模型选择"

  local model_options="claude-sonnet-4（推荐）|claude-opus-4|gemini-2.5-pro|gpt-4o|自定义输入"

  ask_select "模型配置方式？" \
    "一键推荐（所有角色统一使用 claude-sonnet-4）|我要分别配置" \
    MODEL_MODE 0

  if [[ "$MODEL_MODE" == *"推荐"* ]]; then
    MODEL_MODE="recommend"
    IFS='|' read -ra members <<< "$TEAM_MEMBERS"
    for member in "${members[@]}"; do
      set_agent_model "$member" "claude-sonnet-4"
    done
    print_success "所有角色统一使用 claude-sonnet-4"
  else
    MODEL_MODE="custom"
    IFS='|' read -ra members <<< "$TEAM_MEMBERS"
    for member in "${members[@]}"; do
      echo ""
      ask_select "${member}使用什么模型？" "$model_options" _model_choice
      if [[ "$_model_choice" == *"自定义"* ]]; then
        ask_input "请输入模型名称" "claude-sonnet-4" _model_choice
      fi
      # Strip "(推荐)" suffix
      _model_choice=$(echo "$_model_choice" | sed 's/（推荐）//g')
      set_agent_model "$member" "$_model_choice"
      print_success "$member → $_model_choice"
    done
  fi
}

# ════════════════════════════════════════════════════════════════════
#  Step 6: PRD initialization
# ════════════════════════════════════════════════════════════════════
step_prd() {
  print_step 6 7 "PRD 初始化"

  ask_select "你希望如何初始化 PRD？" \
    "生成 PRD 骨架（我稍后自己填写内容）|生成骨架 + 查看完整 PRD 示例（可以参考着写）|跳过（我已有 PRD）" \
    PRD_MODE 0

  case "$PRD_MODE" in
    *"骨架 +"*) PRD_MODE="example" ;;
    *"骨架"*)   PRD_MODE="skeleton" ;;
    *)           PRD_MODE="skip" ;;
  esac

  echo ""
  print_header "🚀 初始化完成后的推荐工作流程"
  echo ""
  print_info "  ① 在 Cursor 中使用 Plan 模式与主 Agent 聊需求细节"
  print_info "     告诉主 Agent：「我要做一个XXX，帮我梳理下需求细节」"
  print_info "     主 Agent 会切换到 Plan 模式，和你一起明确功能、交互等细节"
  echo ""
  print_info "  ② 需求确认后，让产品经理生成 PRD"
  print_info "     告诉主 Agent：「请让产品经理根据刚才的需求讨论生成初版 PRD」"
  print_info "     产品经理 Agent 会自动帮你生成完整的 PRD 文档"
  echo ""
  print_info "  ③ 审阅 PRD，确认无误后，让前端出 UI 设计图"
  print_info "     告诉主 Agent：「PRD 确认没问题，让前端根据 PRD 出一版 UI 设计图」"
  print_info "     前端工程师 Agent 会生成可预览的 HTML 设计稿"
  echo ""
  print_info "  ④ 审阅 UI 设计图，确认后即可开始正式开发"
  print_info "     告诉主 Agent：「UI 没问题，安排各工程师开始开发 Phase 1」"
  echo ""
  print_info "  后续只需维护 PRD，通过主 Agent 分配任务即可推进项目 ✨"
}

# ════════════════════════════════════════════════════════════════════
#  Step 7: Confirm & generate
# ════════════════════════════════════════════════════════════════════
step_confirm() {
  print_step 7 7 "确认并生成"

  # Build summary lines
  local lines=()
  lines+=("项目: ${BOLD}$PROJECT_NAME${NC}")
  lines+=("描述: $PROJECT_DESC")
  lines+=("路径: $PROJECT_DIR")
  lines+=("平台: $PLATFORMS")
  [ "$HAS_FRONTEND" = true ] && lines+=("前端: $TECH_FRONTEND")
  [ "$HAS_MINIAPP" = true ] && lines+=("小程序: $TECH_MINIAPP")
  lines+=("后端: $TECH_BACKEND")
  lines+=("数据库: $TECH_DB")
  [ -n "$TECH_EXTRA" ] && lines+=("其他: $TECH_EXTRA")
  lines+=("团队: $(echo "$TEAM_MEMBERS" | sed 's/|/、/g')")

  # Models
  local model_summary=""
  local all_same=true
  local first_model=""
  IFS='|' read -ra members <<< "$TEAM_MEMBERS"
  for member in "${members[@]}"; do
    local m
    m=$(get_agent_model "$member")
    if [ -z "$first_model" ]; then
      first_model="$m"
    elif [ "$m" != "$first_model" ]; then
      all_same=false
    fi
  done
  if [ "$all_same" = true ]; then
    lines+=("模型: 全部 $first_model")
  else
    for member in "${members[@]}"; do
      lines+=("  $member → $(get_agent_model "$member")")
    done
  fi

  print_box "PRD-Driven AI Team 配置概览" "${lines[@]}"

  echo ""
  echo -e "  ${BOLD}将生成以下文件：${NC}"
  echo -e "    .cursor/agents/"
  IFS='|' read -ra members <<< "$TEAM_MEMBERS"
  for member in "${members[@]}"; do
    local agent_file
    agent_file=$(member_to_filename "$member")
    echo -e "      ${GREEN}$agent_file${NC}"
  done
  echo -e "    .cursor/rules/"
  echo -e "      ${GREEN}project-manager.mdc${NC}"
  echo -e "    docs/"
  [ "$PRD_MODE" != "skip" ] && echo -e "      ${GREEN}PRD.md${NC}"
  [ "$PRD_MODE" = "example" ] && echo -e "      ${GREEN}PRD-example.md${NC}"
  echo -e "    ${GREEN}README.md${NC}"

  echo ""
  if ! ask_confirm "确认生成？"; then
    print_warning "已取消"
    exit 0
  fi
}

# ── Helper: member display name → agent filename ───────────────────
member_to_filename() {
  local member=$1
  case "$member" in
    "产品经理")         echo "product-agent.md" ;;
    "前端开发工程师")   echo "frontend-agent.md" ;;
    "后端开发工程师")   echo "backend-agent.md" ;;
    "测试工程师")       echo "test-agent.md" ;;
    *)
      # Custom role: extract English name from CUSTOM_ROLES
      local eng_name
      eng_name=$(echo "$CUSTOM_ROLES" | tr '|' '\n' | grep ":$member" | cut -d: -f1)
      if [ -n "$eng_name" ]; then
        echo "${eng_name}.md"
      else
        echo "custom-agent.md"
      fi
      ;;
  esac
}

# ── Helper: member display name → agent English name ───────────────
member_to_agentname() {
  local member=$1
  case "$member" in
    "产品经理")         echo "product-agent" ;;
    "前端开发工程师")   echo "frontend-agent" ;;
    "后端开发工程师")   echo "backend-agent" ;;
    "测试工程师")       echo "test-agent" ;;
    *)
      local eng_name
      eng_name=$(echo "$CUSTOM_ROLES" | tr '|' '\n' | grep ":$member" | cut -d: -f1)
      echo "${eng_name:-custom-agent}"
      ;;
  esac
}

# ════════════════════════════════════════════════════════════════════
#  Run all steps
# ════════════════════════════════════════════════════════════════════
run_prompts() {
  step_project_info
  step_platform
  step_tech_stack
  step_env_check
  step_team
  step_models
  step_prd
  step_confirm
}
