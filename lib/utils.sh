#!/usr/bin/env bash
# Bash UI utility functions for interactive CLI

# ── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Print helpers ───────────────────────────────────────────────────
print_header() {
  echo ""
  echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}${BLUE}  $1${NC}"
  echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

print_step() {
  local step_num=$1
  local total=$2
  local title=$3
  echo ""
  echo -e "${BOLD}${CYAN}  [$step_num/$total] $title${NC}"
  echo -e "${DIM}  ─────────────────────────────────────────${NC}"
}

print_success() {
  echo -e "  ${GREEN}✓${NC} $1"
}

print_warning() {
  echo -e "  ${YELLOW}⚠${NC} $1"
}

print_error() {
  echo -e "  ${RED}✗${NC} $1"
}

print_info() {
  echo -e "  ${DIM}$1${NC}"
}

# ── Input: free text with default ───────────────────────────────────
# Usage: ask_input "prompt" "default_value" result_var
ask_input() {
  local prompt=$1
  local default=$2
  local varname=$3
  local input

  if [ -n "$default" ]; then
    echo -ne "  ${BOLD}$prompt${NC} ${DIM}($default)${NC}: "
  else
    echo -ne "  ${BOLD}$prompt${NC}: "
  fi
  read -r input
  if [ -z "$input" ]; then
    input="$default"
  fi
  printf -v "$varname" '%s' "$input"
}

# ── Input: single select ────────────────────────────────────────────
# Usage: ask_select "prompt" "option1|option2|option3" result_var [default_idx]
#   default_idx: 0-based index of default option (direct Enter selects it)
ask_select() {
  local prompt=$1
  IFS='|' read -ra options <<< "$2"
  local varname=$3
  local default_idx=${4:-0}

  echo -e "  ${BOLD}$prompt${NC}"
  for i in "${!options[@]}"; do
    local letter
    letter=$(printf "\\x$(printf '%02x' $((65 + i)))")
    if [ "$i" -eq "$default_idx" ]; then
      echo -e "    ${CYAN}$letter.${NC} ${options[$i]} ${DIM}← 默认${NC}"
    else
      echo -e "    ${CYAN}$letter.${NC} ${options[$i]}"
    fi
  done

  while true; do
    echo -ne "  ${BOLD}请选择${NC} ${DIM}(直接回车选默认)${NC}: "
    read -r choice

    # Direct Enter → use default
    if [ -z "$choice" ]; then
      printf -v "$varname" '%s' "${options[$default_idx]}"
      return 0
    fi

    choice=$(echo "$choice" | tr '[:lower:]' '[:upper:]')
    local idx=$(( $(printf '%d' "'$choice") - 65 ))
    if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#options[@]}" ]; then
      printf -v "$varname" '%s' "${options[$idx]}"
      return 0
    fi
    print_error "无效选择，请重新输入"
  done
}

# ── Input: multi select ─────────────────────────────────────────────
# Usage: ask_multiselect "prompt" "opt1|opt2|opt3" "1,1,0" result_var
#   defaults: comma-separated 1/0 for pre-selected, "r" = required
ask_multiselect() {
  local prompt=$1
  IFS='|' read -ra options <<< "$2"
  IFS=',' read -ra defaults <<< "$3"
  local varname=$4
  local count=${#options[@]}

  local -a selected
  local -a required
  for i in "${!options[@]}"; do
    selected[$i]=${defaults[$i]:-0}
    if [ "${defaults[$i]}" = "r" ]; then
      selected[$i]=1
      required[$i]=1
    else
      required[$i]=0
    fi
  done

  echo -e "  ${BOLD}$prompt${NC} ${DIM}(输入数字切换选中，Enter 确认)${NC}"

  local extra_lines=0
  while true; do
    for i in "${!options[@]}"; do
      local mark="[ ]"
      local suffix=""
      if [ "${selected[$i]}" = "1" ]; then
        mark="${GREEN}[x]${NC}"
      fi
      if [ "${required[$i]}" = "1" ]; then
        suffix=" ${DIM}★必选${NC}"
      fi
      echo -e "    ${mark} ${CYAN}$((i + 1)).${NC} ${options[$i]}${suffix}"
    done

    echo -ne "  ${BOLD}输入数字切换${NC} ${DIM}(直接 Enter 确认)${NC}: "
    read -r toggle

    if [ -z "$toggle" ]; then
      break
    fi

    extra_lines=0
    if [[ "$toggle" =~ ^[0-9]+$ ]] && [ "$toggle" -ge 1 ] && [ "$toggle" -le "$count" ]; then
      local ti=$((toggle - 1))
      if [ "${required[$ti]}" = "1" ]; then
        print_warning "此选项为必选，无法取消"
        extra_lines=1
      elif [ "${selected[$ti]}" = "1" ]; then
        selected[$ti]=0
      else
        selected[$ti]=1
      fi
    else
      print_error "请输入 1-$count 之间的数字"
      extra_lines=1
    fi

    # Erase: options lines + input line + any extra warning/error line
    local erase_count=$((count + 1 + extra_lines))
    for ((ei=0; ei<erase_count; ei++)); do
      echo -ne "\033[1A\033[2K"
    done
  done

  local result=""
  for i in "${!options[@]}"; do
    if [ "${selected[$i]}" = "1" ]; then
      if [ -n "$result" ]; then
        result="$result|${options[$i]}"
      else
        result="${options[$i]}"
      fi
    fi
  done
  eval "$varname='$result'"
}

# ── Confirm yes/no ──────────────────────────────────────────────────
# Usage: ask_confirm "question" [default_yes]
# Returns 0 for yes, 1 for no
ask_confirm() {
  local prompt=$1
  local default=${2:-Y}
  local hint="[Y/n]"
  [ "$default" = "n" ] || [ "$default" = "N" ] && hint="[y/N]"

  echo -ne "  ${BOLD}$prompt${NC} $hint: "
  read -r answer
  answer=${answer:-$default}
  case "$answer" in
    [Yy]*) return 0 ;;
    *) return 1 ;;
  esac
}

# ── Box drawing ─────────────────────────────────────────────────────
print_box() {
  local title=$1
  shift
  local lines=("$@")
  local max_len=0

  for line in "${lines[@]}"; do
    local stripped
    stripped=$(echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#stripped}
    [ "$len" -gt "$max_len" ] && max_len=$len
  done

  local title_stripped
  title_stripped=$(echo -e "$title" | sed 's/\x1b\[[0-9;]*m//g')
  local title_len=${#title_stripped}
  [ "$title_len" -gt "$max_len" ] && max_len=$title_len

  local width=$((max_len + 4))

  echo -ne "  ${CYAN}┌"
  printf '─%.0s' $(seq 1 "$width")
  echo -e "┐${NC}"

  local pad=$(( (width - title_len - 2) / 2 ))
  local pad2=$((width - title_len - 2 - pad))
  echo -ne "  ${CYAN}│${NC}"
  printf ' %.0s' $(seq 1 $((pad + 1)))
  echo -ne "${BOLD}$title${NC}"
  printf ' %.0s' $(seq 1 $((pad2 + 1)))
  echo -e "${CYAN}│${NC}"

  echo -ne "  ${CYAN}├"
  printf '─%.0s' $(seq 1 "$width")
  echo -e "┤${NC}"

  for line in "${lines[@]}"; do
    local stripped
    stripped=$(echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#stripped}
    local rpad=$((width - len - 2))
    echo -ne "  ${CYAN}│${NC} $line"
    printf ' %.0s' $(seq 1 "$rpad")
    echo -e " ${CYAN}│${NC}"
  done

  echo -ne "  ${CYAN}└"
  printf '─%.0s' $(seq 1 "$width")
  echo -e "┘${NC}"
}
