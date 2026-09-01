#!/bin/sh
input=$(cat)

# One jq pass, tab-separated: everything below comes from the statusline JSON
IFS=$(printf '\t') read -r model dir style effort ctx pr pr_url <<EOF
$(printf '%s' "$input" | jq -r '[
  .model.display_name // "unknown",
  .workspace.current_dir // .cwd // "",
  .output_style.name // "",
  .effort.level // "",
  (.context_window.used_percentage // "" | tostring),
  (.pr.number // "" | tostring),
  .pr.url // ""
] | @tsv')
EOF

# effort is only present on reasoning models; fall back to the configured level
if [ -z "$effort" ]; then
  effort=$(jq -r '.effortLevel // ""' "$HOME/.claude/settings.json" 2>/dev/null)
fi
# show the effort level in brackets, not the output style
style="$effort"

# directory name only, not the full path
if [ "$dir" = "$HOME" ]; then
  dirname_short="~"
else
  dirname_short=$(basename "$dir")
fi

# Get git branch (skip optional locks to avoid blocking)
branch=""
if [ -n "$dir" ] && git -C "$dir" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$dir" -c core.useBuiltinFSMonitor=false symbolic-ref --short HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null)
fi

ctx_pct=""
if [ -n "$ctx" ]; then
  ctx_pct=$(awk -v p="$ctx" 'BEGIN { printf "%.1f", p }' 2>/dev/null)
fi

# cyan model, yellow effort, blue dir, green branch, orange PR, magenta context
printf "\033[36m%s\033[0m" "$model"

if [ -n "$style" ]; then
  printf " \033[33m[%s]\033[0m" "$style"
fi

if [ -n "$dirname_short" ]; then
  printf " \033[34m%s\033[0m" "$dirname_short"
fi

if [ -n "$branch" ]; then
  printf " \033[32m(%s)\033[0m" "$branch"
fi

if [ -n "$pr" ]; then
  if [ -n "$pr_url" ]; then
    # OSC 8 hyperlink: clickable in terminals that support it
    printf " \033[38;5;208m\033]8;;%s\007PR #%s\033]8;;\007\033[0m" "$pr_url" "$pr"
  else
    printf " \033[38;5;208mPR #%s\033[0m" "$pr"
  fi
fi

if [ -n "$ctx_pct" ]; then
  printf " \033[35m%s%%\033[0m" "$ctx_pct"
fi

printf "\n"
