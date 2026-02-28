#!/usr/bin/env bash
# File generator — renders templates and writes output files

_GENERATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$_GENERATOR_DIR/../templates"

# ── Template rendering ──────────────────────────────────────────────
# Simple variable substitution: replaces {{VAR}} with value
render_template() {
  local template_file=$1
  local output_file=$2
  shift 2

  local content
  content=$(<"$template_file")

  # Apply variable substitutions passed as key=value pairs
  while [ $# -gt 0 ]; do
    local key="${1%%=*}"
    local value="${1#*=}"
    # Escape special sed characters in value
    local escaped_value
    escaped_value=$(printf '%s' "$value" | sed 's/[&/\]/\\&/g')
    content=$(echo "$content" | sed "s|{{${key}}}|${escaped_value}|g")
    shift
  done

  mkdir -p "$(dirname "$output_file")"
  echo "$content" > "$output_file"
}

# ── Multi-line template rendering ───────────────────────────────────
# Renders a template file with key=value substitutions (supports multi-line values).
# Writes a replacements manifest file, then uses python3 to apply them.
render_template_multiline() {
  local template_file=$1
  local output_file=$2
  shift 2

  mkdir -p "$(dirname "$output_file")"

  # Build a replacements file: each entry is KEY\nVALUE\n<SEP>\n
  local manifest
  manifest=$(mktemp)
  while [ $# -gt 0 ]; do
    local key="${1%%=*}"
    local value="${1#*=}"
    echo "$key" >> "$manifest"
    echo "$value" >> "$manifest"
    echo "___TPLSEP___" >> "$manifest"
    shift
  done

  PYTHONIOENCODING=utf-8 python3 - "$template_file" "$output_file" "$manifest" << 'PYEOF'
import sys, os

template_file = sys.argv[1]
output_file = sys.argv[2]
manifest_file = sys.argv[3]

with open(template_file, 'r', encoding='utf-8', errors='replace') as f:
    content = f.read()

with open(manifest_file, 'r', encoding='utf-8', errors='replace') as f:
    raw = f.read()

entries = raw.split('___TPLSEP___\n')
for entry in entries:
    entry = entry.strip('\n')
    if not entry:
        continue
    nl = entry.find('\n')
    if nl == -1:
        continue
    key = entry[:nl]
    val = entry[nl+1:]
    content = content.replace('{{' + key + '}}', val)

os.makedirs(os.path.dirname(output_file) or '.', exist_ok=True)
with open(output_file, 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF

  rm -f "$manifest"
}

# ── Build tech stack summary ────────────────────────────────────────
build_tech_summary() {
  local parts=()
  [ -n "$TECH_FRONTEND" ] && parts+=("$TECH_FRONTEND")
  [ -n "$TECH_MINIAPP" ] && parts+=("$TECH_MINIAPP")
  [ -n "$TECH_BACKEND" ] && parts+=("$TECH_BACKEND")
  [ -n "$TECH_DB" ] && parts+=("$TECH_DB")
  [ -n "$TECH_EXTRA" ] && parts+=("$TECH_EXTRA")

  local IFS=", "
  echo "${parts[*]}"
}

# ── Build tech table for README ─────────────────────────────────────
build_tech_table() {
  local table=""
  if [ -n "$TECH_FRONTEND" ]; then
    table+="| 前端（Web） | $TECH_FRONTEND |\n"
  fi
  if [ -n "$TECH_MINIAPP" ]; then
    table+="| 前端（小程序） | $TECH_MINIAPP |\n"
  fi
  table+="| 后端服务 | $TECH_BACKEND |\n"
  table+="| 数据库 | $TECH_DB |"
  [ -n "$TECH_EXTRA" ] && table+="\n| 其他 | $TECH_EXTRA |"
  echo -e "$table"
}

# ── Build team diagram for README ───────────────────────────────────
build_team_diagram() {
  local diagram=""
  diagram+="┌─────────────────────────────────────────────────────────┐\n"
  diagram+="│                  主 Agent（项目经理）                      │\n"
  diagram+="│                                                         │\n"
  diagram+="│  职责：任务调度、进度把控、子代理协调、Bug分流、与用户沟通  │\n"
  diagram+="│  核心能力：在同一条消息中并行启动多个子代理               │\n"
  diagram+="└───┬──────────"

  IFS='|' read -ra members <<< "$TEAM_MEMBERS"
  local count=${#members[@]}

  # Build connector line
  local connector="    │"
  for ((i=1; i<count; i++)); do
    connector+="          │"
  done
  diagram+="$(printf '┬%.0s' $(seq 2 $count))────────────┘\n"
  diagram+="$connector\n"

  # Build boxes
  for member in "${members[@]}"; do
    local agent_name
    agent_name=$(member_to_agentname "$member")
    diagram+="┌───▼────┐ "
  done
  diagram+="\n"

  for member in "${members[@]}"; do
    local agent_name
    agent_name=$(member_to_agentname "$member")
    local padded
    padded=$(printf "%-8s" "$agent_name")
    diagram+="│${padded}│ "
  done
  diagram+="\n"

  for member in "${members[@]}"; do
    diagram+="└────────┘ "
  done

  echo -e "$diagram"
}

# ── Build agent roles detail for README ─────────────────────────────
build_agent_roles_detail() {
  local detail=""
  local section_num=3
  IFS='|' read -ra members <<< "$TEAM_MEMBERS"

  for member in "${members[@]}"; do
    local agent_name agent_file
    agent_name=$(member_to_agentname "$member")
    agent_file=$(member_to_filename "$member")

    detail+="### 2.${section_num} ${agent_name}（${member}）\n\n"
    detail+="**配置文件**：\`.cursor/agents/${agent_file}\`\n\n"
    local _m
    _m=$(get_agent_model "$member")
    detail+="**模型**：${_m}\n\n"
    section_num=$((section_num + 1))
  done

  echo -e "$detail"
}

# ── Build frontend duties based on platform ─────────────────────────
build_frontend_duties() {
  local duties=""

  if [ "$HAS_FRONTEND" = true ]; then
    duties+="- 使用 $TECH_FRONTEND 进行 Web 应用开发\n"
    duties+="- 实现页面结构、样式和交互逻辑\n"
    duties+="- 与后端 API 对接，处理数据请求与状态管理\n"
    duties+="- 实现组件化开发，保证代码复用性和可维护性\n"
  fi

  if [ "$HAS_MINIAPP" = true ]; then
    duties+="- 使用 $TECH_MINIAPP 进行小程序开发\n"
    duties+="- 处理小程序生命周期、路由、权限等特性\n"
    duties+="- 对接小程序平台 API 和组件规范\n"
  fi

  echo -e "$duties"
}

# ── Build frontend tech stack detail ────────────────────────────────
build_frontend_tech_detail() {
  local detail=""
  if [ "$HAS_FRONTEND" = true ]; then
    detail+="### Web 前端\n- $TECH_FRONTEND\n"
  fi
  if [ "$HAS_MINIAPP" = true ]; then
    detail+="\n### 小程序\n- $TECH_MINIAPP\n"
  fi
  echo -e "$detail"
}

# ── Build backend tech stack detail ─────────────────────────────────
build_backend_tech_detail() {
  local detail="- $TECH_BACKEND\n- 数据库：$TECH_DB"
  [ -n "$TECH_EXTRA" ] && detail+="\n- $TECH_EXTRA"
  echo -e "$detail"
}

# ── Build Web E2E section for test-agent ─────────────────────────────
build_web_e2e_section() {
  if [ "$HAS_FRONTEND" = true ]; then
    cat << 'WEB_E2E_EOF'
### Web 页面 E2E 测试（Playwright）

使用 Playwright 对管理后台/Web 页面进行端到端自动化测试。

#### Playwright 使用规范
- 项目前端目录下安装 Playwright：`npm install -D @playwright/test && npx playwright install`
- 测试脚本存放在前端项目的 `e2e/` 目录，文件命名 `*.spec.ts`
- 运行测试：`npx playwright test e2e/xxx.spec.ts`
- 截图保存到 `test-screenshots/` 目录

#### 测试覆盖要求
- 登录/登出流程
- 核心页面导航和菜单切换
- 表单提交（含校验、成功/失败反馈）
- 列表展示（分页、筛选、搜索）
- 弹窗确认（删除、审核等操作）
- 文件上传/下载

#### Playwright 常用 API

| API | 说明 |
|-----|------|
| `page.goto(url)` | 导航到指定页面 |
| `page.click(selector)` | 点击元素 |
| `page.fill(selector, value)` | 填写输入框 |
| `page.waitForSelector(selector)` | 等待元素出现 |
| `page.screenshot({ path })` | 页面截图 |
| `expect(locator).toBeVisible()` | 断言元素可见 |
| `expect(locator).toHaveText(text)` | 断言元素文本 |
| `page.locator(selector)` | 定位元素 |
WEB_E2E_EOF
  fi
}

build_web_e2e_tech() {
  if [ "$HAS_FRONTEND" = true ]; then
    echo "- Web E2E：Playwright"
  fi
}

# ── Build miniapp test section for test-agent ───────────────────────
build_miniapp_test_section() {
  if [ "$HAS_MINIAPP" = true ]; then
    cat << 'MINIAPP_EOF'
### 小程序自动化测试（miniprogram-automator）

使用微信官方 miniprogram-automator SDK 控制微信开发者工具，对小程序进行自动化 E2E 测试。

#### 环境要求
- 本地已安装微信开发者工具，且已登录
- 微信开发者工具需开启"服务端口"（设置 → 安全设置 → 服务端口 → 开启）
- Node.js 环境已就绪

#### 安装与配置
```bash
cd <小程序项目目录>
npm init -y  # 如果没有 package.json
npm install miniprogram-automator jest --save-dev
```

#### 测试脚本规范
- 测试脚本存放在小程序项目的 `e2e/` 目录
- 文件命名：`xxx.test.js`
- 截图保存到 `test-screenshots/` 目录
- 运行测试：`npx jest e2e/xxx.test.js --forceExit --testTimeout=120000`

#### miniprogram-automator 常用 API

| API | 说明 |
|-----|------|
| `automator.launch({ cliPath, projectPath })` | 启动开发者工具并打开项目 |
| `miniProgram.reLaunch(path)` | 关闭所有页面并打开指定页面 |
| `miniProgram.switchTab(path)` | 切换 TabBar 页面 |
| `miniProgram.currentPage()` | 获取当前页面实例 |
| `page.$(selector)` | 查找页面元素 |
| `page.$$(selector)` | 查找所有匹配元素 |
| `page.waitFor(ms \| selector)` | 等待时间或元素出现 |
| `element.tap()` | 点击元素 |
| `element.input(text)` | 输入文本 |
| `page.data` | 获取页面 data（用于断言） |
| `page.callMethod(method, ...args)` | 调用页面方法 |

#### 注意事项
- `cliPath` 在 macOS 上为 `/Applications/wechatwebdevtools.app/Contents/MacOS/cli`
- `cliPath` 在 Windows 上为开发者工具安装目录下的 `cli.bat`
- 首次运行需确保开发者工具已登录微信账号
- 测试时小程序处于开发模式，直连 localhost 后端
- 运行前确保后端服务已启动

#### 小程序测试标准流程（必须严格遵守）

##### 第一步：理解业务逻辑
- 阅读 `docs/PRD.md` 中小程序相关页面的 PRD 描述
- 阅读所有页面的 `.js` 和 `.wxml` 文件，掌握页面数据结构和元素选择器

##### 第二步：检查当前数据状态
- 通过 curl 调用后端 API，检查系统中的数据是否满足测试需求

##### 第三步：准备测试数据
- 确保系统中存在覆盖各业务场景的数据（各状态的记录等）
- 如缺少则通过 API 创建

##### 第四步：编写并执行业务场景测试
- 按核心业务场景组织测试，而不是按页面
- 覆盖完整的用户操作流程

##### 第五步：数据断言要求
- **禁止**只检查"元素是否存在"就算通过
- **必须**用 `page.data` 获取页面数据，断言关键字段的值和结构
- **必须**验证数据的业务正确性
MINIAPP_EOF
  fi
}

build_miniapp_tech() {
  if [ "$HAS_MINIAPP" = true ]; then
    echo "- 小程序 E2E：miniprogram-automator + Jest"
  fi
}

# ── Install Cursor Skills ────────────────────────────────────────────
# Checks if required skills exist in ~/.cursor/skills/, installs if missing
install_cursor_skills() {
  local skills_dir="$HOME/.cursor/skills"
  local need_install=false

  echo ""
  print_info "检查 Cursor 前端技能..."

  # Check web-design-guidelines
  if [ -f "$skills_dir/web-design-guidelines/SKILL.md" ]; then
    print_success "web-design-guidelines — 已安装"
  else
    print_warning "web-design-guidelines — 未安装"
    need_install=true
  fi

  # Check frontend-design
  if [ -f "$skills_dir/frontend-design/SKILL.md" ]; then
    print_success "frontend-design — 已安装"
  else
    print_warning "frontend-design — 未安装"
    need_install=true
  fi

  if [ "$need_install" = true ]; then
    if ask_confirm "是否自动安装缺少的 Cursor 技能？"; then
      mkdir -p "$skills_dir"

      # Install web-design-guidelines
      if [ ! -f "$skills_dir/web-design-guidelines/SKILL.md" ]; then
        mkdir -p "$skills_dir/web-design-guidelines"
        cat > "$skills_dir/web-design-guidelines/SKILL.md" << 'SKILL_WDG'
---
name: web-design-guidelines
description: Review UI code for Web Interface Guidelines compliance. Use when asked to "review my UI", "check accessibility", "audit design", "review UX", or "check my site against best practices".
metadata:
  author: vercel
  version: "1.0.0"
  argument-hint: <file-or-pattern>
---

# Web Interface Guidelines

Review files for compliance with Web Interface Guidelines.

## How It Works

1. Fetch the latest guidelines from the source URL below
2. Read the specified files (or prompt user for files/pattern)
3. Check against all rules in the fetched guidelines
4. Output findings in the terse `file:line` format

## Guidelines Source

Fetch fresh guidelines before each review:

```
https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md
```

Use WebFetch to retrieve the latest rules. The fetched content contains all the rules and output format instructions.

## Usage

When a user provides a file or pattern argument:
1. Fetch guidelines from the source URL above
2. Read the specified files
3. Apply all rules from the fetched guidelines
4. Output findings using the format specified in the guidelines

If no files specified, ask the user which files to review.
SKILL_WDG
        print_success "web-design-guidelines 安装完成"
      fi

      # Install frontend-design
      if [ ! -f "$skills_dir/frontend-design/SKILL.md" ]; then
        mkdir -p "$skills_dir/frontend-design"
        cat > "$skills_dir/frontend-design/SKILL.md" << 'SKILL_FD'
---
name: frontend-design
description: Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, or applications. Generates creative, polished code that avoids generic AI aesthetics.
---
This skill guides creation of distinctive, production-grade frontend interfaces that avoid generic "AI slop" aesthetics. Implement real working code with exceptional attention to aesthetic details and creative choices.
The user provides frontend requirements: a component, page, application, or interface to build. They may include context about the purpose, audience, or technical constraints.
## Design Thinking
Before coding, understand the context and commit to a BOLD aesthetic direction:
- **Purpose**: What problem does this interface solve? Who uses it?
- **Tone**: Pick an extreme: brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian, etc.
- **Constraints**: Technical requirements (framework, performance, accessibility).
- **Differentiation**: What makes this UNFORGETTABLE? What's the one thing someone will remember?
**CRITICAL**: Choose a clear conceptual direction and execute it with precision.
Then implement working code (HTML/CSS/JS, React, Vue, etc.) that is:
- Production-grade and functional
- Visually striking and memorable
- Cohesive with a clear aesthetic point-of-view
- Meticulously refined in every detail
## Frontend Aesthetics Guidelines
Focus on:
- **Typography**: Choose fonts that are beautiful, unique, and interesting. Avoid generic fonts like Arial and Inter.
- **Color & Theme**: Commit to a cohesive aesthetic. Use CSS variables for consistency.
- **Motion**: Use animations for effects and micro-interactions. Focus on high-impact moments.
- **Spatial Composition**: Unexpected layouts. Asymmetry. Overlap. Generous negative space OR controlled density.
- **Backgrounds & Visual Details**: Create atmosphere and depth. Apply creative forms like gradient meshes, noise textures, geometric patterns.
NEVER use generic AI-generated aesthetics like overused font families, cliched color schemes, predictable layouts, and cookie-cutter design.
SKILL_FD
        print_success "frontend-design 安装完成"
      fi
    else
      print_info "跳过技能安装。你可以稍后手动安装到 ~/.cursor/skills/"
    fi
  fi
}

# ════════════════════════════════════════════════════════════════════
#  Generate all files
# ════════════════════════════════════════════════════════════════════
generate_files() {
  local target_dir="$PROJECT_DIR"
  local tech_summary
  tech_summary=$(build_tech_summary)
  local platforms_display
  platforms_display=$(echo "$PLATFORMS" | sed 's/|/、/g')

  echo ""
  print_info "正在生成文件..."

  # ── Create directory structure ──
  mkdir -p "$target_dir/.cursor/agents"
  mkdir -p "$target_dir/docs"

  # ── Generate agent configs ──
  IFS='|' read -ra members <<< "$TEAM_MEMBERS"
  for member in "${members[@]}"; do
    local agent_name agent_file template_file model
    agent_name=$(member_to_agentname "$member")
    agent_file=$(member_to_filename "$member")
    model=$(get_agent_model "$member")

    # Determine template
    case "$member" in
      "产品经理")
        template_file="$TEMPLATE_DIR/agents/product-agent.md.tpl"
        render_template_multiline "$template_file" "$target_dir/.cursor/agents/$agent_file" \
          "MODEL=$model" \
          "PROJECT_NAME=$PROJECT_NAME" \
          "PROJECT_DESC=$PROJECT_DESC" \
          "PLATFORMS=$platforms_display" \
          "TECH_STACK_SUMMARY=$tech_summary"
        ;;
      "前端开发工程师")
        template_file="$TEMPLATE_DIR/agents/frontend-agent.md.tpl"
        local frontend_duties frontend_tech
        frontend_duties=$(build_frontend_duties)
        frontend_tech=$(build_frontend_tech_detail)
        render_template_multiline "$template_file" "$target_dir/.cursor/agents/$agent_file" \
          "MODEL=$model" \
          "PROJECT_NAME=$PROJECT_NAME" \
          "FRONTEND_DUTIES=$frontend_duties" \
          "TECH_STACK_DETAIL=$frontend_tech"
        ;;
      "后端开发工程师")
        template_file="$TEMPLATE_DIR/agents/backend-agent.md.tpl"
        local backend_tech
        backend_tech=$(build_backend_tech_detail)
        render_template_multiline "$template_file" "$target_dir/.cursor/agents/$agent_file" \
          "MODEL=$model" \
          "PROJECT_NAME=$PROJECT_NAME" \
          "TECH_STACK_DETAIL=$backend_tech"
        ;;
      "测试工程师")
        template_file="$TEMPLATE_DIR/agents/test-agent.md.tpl"
        local web_e2e_section web_e2e_tech miniapp_section miniapp_tech
        web_e2e_section=$(build_web_e2e_section)
        web_e2e_tech=$(build_web_e2e_tech)
        miniapp_section=$(build_miniapp_test_section)
        miniapp_tech=$(build_miniapp_tech)
        render_template_multiline "$template_file" "$target_dir/.cursor/agents/$agent_file" \
          "MODEL=$model" \
          "PROJECT_NAME=$PROJECT_NAME" \
          "WEB_E2E_SECTION=$web_e2e_section" \
          "WEB_E2E_TECH=$web_e2e_tech" \
          "MINIAPP_TEST_SECTION=$miniapp_section" \
          "MINIAPP_TECH=$miniapp_tech"
        ;;
      *)
        template_file="$TEMPLATE_DIR/agents/custom-agent.md.tpl"
        local custom_desc
        custom_desc=$(echo "$CUSTOM_ROLES" | tr '|' '\n' | grep "^$agent_name:" | cut -d: -f2-)
        render_template_multiline "$template_file" "$target_dir/.cursor/agents/$agent_file" \
          "MODEL=$model" \
          "AGENT_NAME=$agent_name" \
          "AGENT_DESC=${custom_desc:-$member}" \
          "AGENT_TITLE=$member" \
          "PROJECT_NAME=$PROJECT_NAME"
        ;;
    esac
    print_success ".cursor/agents/$agent_file"
  done

  # ── Generate README ──
  local tech_table team_diagram agent_roles_detail
  tech_table=$(build_tech_table)
  team_diagram=$(build_team_diagram)
  agent_roles_detail=$(build_agent_roles_detail)

  render_template_multiline "$TEMPLATE_DIR/README.md.tpl" "$target_dir/README.md" \
    "PROJECT_NAME=$PROJECT_NAME" \
    "PROJECT_DESC=$PROJECT_DESC" \
    "TECH_TABLE=$tech_table" \
    "TEAM_DIAGRAM=$team_diagram" \
    "AGENT_ROLES_DETAIL=$agent_roles_detail"
  print_success "README.md"

  # ── Generate PRD ──
  if [ "$PRD_MODE" != "skip" ]; then
    render_template_multiline "$TEMPLATE_DIR/PRD-skeleton.md.tpl" "$target_dir/docs/PRD.md" \
      "PROJECT_NAME=$PROJECT_NAME" \
      "PROJECT_DESC=$PROJECT_DESC" \
      "PLATFORMS=$platforms_display"
    print_success "docs/PRD.md"
  fi

  if [ "$PRD_MODE" = "example" ]; then
    if [ -f "$TEMPLATE_DIR/PRD-example.md" ]; then
      cp "$TEMPLATE_DIR/PRD-example.md" "$target_dir/docs/PRD-example.md"
      print_success "docs/PRD-example.md"
    fi
  fi

  # ── Install Cursor Skills (for frontend-agent) ──
  if [[ "$TEAM_MEMBERS" == *"前端开发工程师"* ]]; then
    install_cursor_skills
  fi

  # ── Done ──
  echo ""
  echo -e "${GREEN}${BOLD}  ✓ AI 开发团队初始化完成！${NC}"
  echo ""
  echo -e "  ${BOLD}下一步：${NC}"
  echo -e "  1. 用 Cursor 打开项目目录：${CYAN}$target_dir${NC}"
  echo -e "  2. 使用 ${BOLD}Plan 模式${NC}与主 Agent 聊需求细节："
  echo -e "     ${DIM}「我要做一个XXX，帮我梳理下需求细节」${NC}"
  echo -e "  3. 需求确认后，让产品经理生成 PRD："
  echo -e "     ${DIM}「请让产品经理根据刚才的需求讨论生成初版 PRD」${NC}"
  echo -e "  4. 审阅 PRD 确认无误后，让前端出 UI 设计图："
  echo -e "     ${DIM}「PRD 没问题，让前端根据 PRD 出一版 UI 设计图」${NC}"
  echo -e "  5. 审阅 UI 设计图，确认后开始开发："
  echo -e "     ${DIM}「UI 没问题，安排各工程师开始开发 Phase 1」${NC}"
  echo -e "  6. 后续只需维护 ${CYAN}docs/PRD.md${NC}，通过主 Agent 分配任务即可推进项目"
  echo ""
  echo -e "  ${DIM}📖 了解更多：https://github.com/wirechen/PRD-Driven_AI_Team_For_Cursor${NC}"
  echo ""
}
