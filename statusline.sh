#!/usr/bin/env bash
# Claude Code status line (macOS / Linux, bash + jq)
# Line 1: model, folder, context window usage
# Line 2: 5-hour and weekly plan limits with reset times
# Bars are drawn with background-colored spaces, so they look solid in any font.

input=$(cat)
command -v jq >/dev/null 2>&1 || { echo "statusline: jq is required (brew install jq)"; exit 0; }

# One jq call; unit-separator delimited so empty fields survive `read`.
IFS=$'\x1f' read -r model dir ctx h5_pct h5_ts wk_pct wk_ts < <(
  printf '%s' "$input" | jq -r '[
    (.model.display_name // "Claude"),
    (.workspace.current_dir // ""),
    (.context_window.used_percentage // ""),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""),
    (.rate_limits.seven_day.resets_at // "")
  ] | map(tostring) | join("\u001f")'
)

esc=$'\033'
reset="${esc}[0m"
cyan="${esc}[38;5;80m"
dim="${esc}[38;5;245m"
bg_green="${esc}[48;5;71m"
bg_yellow="${esc}[48;5;178m"
bg_red="${esc}[48;5;167m"
bg_empty="${esc}[48;5;238m"

# Integer percent clamped to 0-100 (rounded).
clamp() { awk -v p="$1" 'BEGIN { p += 0; if (p < 0) p = 0; if (p > 100) p = 100; printf "%d", p + 0.5 }'; }

spaces() { local n=$1 s=""; while [ "$n" -gt 0 ]; do s+=" "; n=$((n-1)); done; printf '%s' "$s"; }

bar() {
  local pct width=10 filled fill
  pct=$(awk -v p="$1" 'BEGIN { p += 0; if (p < 0) p = 0; if (p > 100) p = 100; print p }')
  filled=$(awk -v p="$pct" -v w="$width" 'BEGIN { printf "%d", p * w / 100 }')
  if   awk -v p="$pct" 'BEGIN { exit !(p >= 90) }'; then fill=$bg_red
  elif awk -v p="$pct" 'BEGIN { exit !(p >= 70) }'; then fill=$bg_yellow
  else fill=$bg_green; fi
  local out=""
  [ "$filled" -gt 0 ] && out+="${fill}$(spaces "$filled")"
  [ "$filled" -lt "$width" ] && out+="${bg_empty}$(spaces $((width - filled)))"
  printf '%s%s' "$out" "$reset"
}

time_left() {
  local s=$(( ${1%.*} - $(date +%s) ))
  [ "$s" -le 0 ] && { printf 'now'; return; }
  local d=$((s / 86400)) h=$(((s % 86400) / 3600)) m=$(((s % 3600) / 60))
  if   [ "$d" -gt 0 ]; then printf '%dd %dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '%dh %dm' "$h" "$m"
  else printf '%dm' "$m"; fi
}

# Local time of a unix timestamp; works with BSD (macOS) and GNU date.
fmt_at() {
  local ts=${1%.*}
  LC_ALL=C date -r "$ts" +"$2" 2>/dev/null || LC_ALL=C date -d "@$ts" +"$2"
}

# ---- Line 1: model | folder | context ----
line1="${cyan}[${model}]${reset}"
[ -n "$dir" ] && line1+=" ${dir##*/}"
if [ -n "$ctx" ]; then
  line1+="  ${dim}|${reset}  Context $(bar "$ctx") $(clamp "$ctx")%"
fi
printf '%s\n' "$line1"

# ---- Line 2: plan limits ----
parts=()
if [ -n "$h5_pct" ]; then
  t="5-hour limit $(bar "$h5_pct") $(clamp "$h5_pct")%"
  [ -n "$h5_ts" ] && t+="  ${dim}resets in $(time_left "$h5_ts") ($(fmt_at "$h5_ts" '%H:%M'))${reset}"
  parts+=("$t")
fi
if [ -n "$wk_pct" ]; then
  t="Weekly limit $(bar "$wk_pct") $(clamp "$wk_pct")%"
  [ -n "$wk_ts" ] && t+="  ${dim}resets in $(time_left "$wk_ts") ($(fmt_at "$wk_ts" '%a %d %b, %H:%M'))${reset}"
  parts+=("$t")
fi
if [ "${#parts[@]}" -gt 0 ]; then
  sep="  ${dim}|${reset}  "
  out=${parts[0]}
  for p in "${parts[@]:1}"; do out+="${sep}${p}"; done
  printf '%s\n' "$out"
fi
