#!/usr/bin/env bash

trap 'echo -e "\nВыход по Ctrl+C"; exit' SIGINT

SEARCH_DIR="$HOME"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMPTY_IMAGE="$SCRIPT_DIR/empty.png"

EXCLUDE_DIRS=(".git" "node_modules" ".cache" "/proc" "/run" "/tmp" "/var/cache")

BASE_OPTIONS_FZF=(
  --bind "enter:execute:open_file {}"
  --preview-window=right:70%
  --bind="focus:transform-preview-label:echo [ {} ]"
  --bind="ctrl-p:toggle-preview+transform-preview-label:echo [ {} ]"
  --color='input-border:226,input-label:226'
  --list-border
  --bind 'result:transform-list-label:
        if [[ -z $FZF_QUERY ]]; then
          echo " $FZF_MATCH_COUNT items "
        else
          echo " $FZF_MATCH_COUNT matches for \"$FZF_QUERY\" "
        fi
        '
  --border --border-label="C-c | Esc - exit || C-p - toggle preview"
  --input-border --info=right
)

FD_EXCLUDES=()
RG_EXCLUDES=()
for dir in "${EXCLUDE_DIRS[@]}"; do
  FD_EXCLUDES+=(--exclude "$dir")
  RG_EXCLUDES+=(--glob "!$dir")
done

if [ -n "$BAT_THEME"]; then
  BAT_THEME="Nord"
fi

export BAT_THEME

preview_file() {
  local file="$1"
  local mime_type=$(file --mime-type -b "$file" 2>/dev/null)

  case "$mime_type" in
  image/*)
    echo -e "\n\033[1;36m📸 Picture:\033[0m $file"
    echo -e "\033[1;33m📊 MIME type:\033[0m $mime_type"
    echo -e "\033[1;33m📊 Size:\033[0m $(identify -format '%wx%h' "$file" 2>/dev/null || echo 'unknown')"
    echo
    kitty icat --clear --transfer-mode=memory --stdin=no --place="${FZF_PREVIEW_COLUMNS}x$((FZF_PREVIEW_LINES - 6))@0x0" "$file"
    ;;
  video/*)
    kitty icat --clear --transfer-mode=memory --stdin=no "$EMPTY_IMAGE" #show empty image for clear image from "image/*"
    echo -e "\033[1;35m🎥 Video file:\033[0m $file"
    echo -e "\033[1;33m📊 MIME type:\033[0m $mime_type"
    echo -e "\033[1;33m💾 Size:\033[0m $(stat -c%s "$file" 2>/dev/null | numfmt --to=iec || echo 'unknown')"
    ;;
  audio/*)
    kitty icat --clear --transfer-mode=memory --stdin=no "$EMPTY_IMAGE" #show empty image for clear image from "image/*"
    echo -e "\033[1;34m🎵 Audio file:\033[0m $file"
    echo -e "\033[1;33m📊 MIME type:\033[0m $mime_type"
    echo -e "\033[1;33m💾 Size:\033[0m $(stat -c%s "$file" 2>/dev/null | numfmt --to=iec || echo 'unknown')"
    ;;
  application/pdf)
    kitty icat --clear --transfer-mode=memory --stdin=no "$EMPTY_IMAGE" #show empty image for clear image from "image/*"
    echo -e "\033[1;31m📕 PDF doc:\033[0m $file"
    echo -e "\033[1;33m📊 MIME type:\033[0m $mime_type"
    echo -e "\033[1;33m💾 Size:\033[0m $(stat -c%s "$file" 2>/dev/null | numfmt --to=iec || echo 'unknown')"
    ;;
  text/* | application/json | application/xml | application/javascript | application/x-sh | application/x-shellscript)
    kitty icat --clear --transfer-mode=memory --stdin=no "$EMPTY_IMAGE" #show empty image for clear image from "image/*"
    bat --color=always --theme="$BAT_THEME" --style=numbers --line-range=:100 "$file" 2>/dev/null || head -n 100 "$file"
    ;;
  *)
    kitty icat --clear --transfer-mode=memory --stdin=no "$EMPTY_IMAGE" #show empty image for clear image from "image/*"
    echo -e "\033[1;37m📄 File:\033[0m $(basename "$file")"
    echo -e "\033[1;33m📁 Full path:\033[0m $file"
    echo -e "\033[1;33m📊 MIME type:\033[0m $mime_type"
    echo -e "\033[1;33m💾 Size:\033[0m $(stat -c%s "$file" 2>/dev/null | numfmt --to=iec || echo 'unknown')"
    ;;
  esac
}

open_file() {
  echo "Open file: $1" >&2
  local file="$1"
  [[ -f "$file" ]] || {
    echo "No such file: $file" >&2
    return 1
  }
  local mime
  mime=$(file --mime-type -b "$file")

  case "$mime" in
  text/*)
    kitty --config /dev/null -e bash -lc "nvim '$file'" 2>/dev/null &
    ;;
  image/*)
    imv "$file" 2>/dev/null &
    ;;
  video/*)
    vlc "$file" 2>/dev/null &
    ;;
  application/pdf)
    zathura "$file" 2>/dev/null &
    ;;
  audio/*)
    vlc "$file" 2>/dev/null &
    ;;
  *)
    echo "$file" | wl-copy -n
    notify-send "Path to file copy to clipboard" "$(basename "$file")" -i clipboard -t 1500
    echo "Path was copy to clipboard: $file" >&2
    ;;
  esac
}

preview_content_file() {
  local file="$1"
  local query="$2"
  [ -z "$file" ] && return
  [ ! -f "$file" ] && return

  # get numbers for all matches
  mapfile -t lines < <(
    rg -F -n --no-heading --color=never "$query" "$file" 2>/dev/null |
      cut -d: -f1 | sort -n -u
  )

  local first_line=1
  [ ${#lines[@]} -gt 0 ] && first_line=${lines[0]}

  local preview_lines=${FZF_PREVIEW_LINES:-30}

  # compute first line for centering
  local start_line=$((first_line - preview_lines / 2))
  [ "$start_line" -lt 1 ] && start_line=1

  # generate args --highlight-line for matches
  local hl_args=()
  for l in "${lines[@]}"; do
    hl_args+=(--highlight-line="$l")
  done
  #echo "───── ${#lines[@]}  matches ─────"
  bat --color=always --theme="$BAT_THEME" --style=numbers --paging=never "${hl_args[@]}" "$file"
}
# export func for childe-shell
export -f open_file
export -f preview_file
export -f preview_content_file

SHELL=$(which bash)

while [[ 1 ]]; do

  # Меню выбора режима
  choice=$(printf "🔍 Search by file name\n🧠 Search by content\n❌ Exit" |
    fzf --phony \
      --border \
      --border-label="C-c|Esc - exit || C-p - toggle preview")

  case "$choice" in
  "🔍 Search by file name")
    fd "" "$SEARCH_DIR" --type f --hidden --no-ignore "${FD_EXCLUDES[@]}" 2>/dev/null |
      fzf --ansi --height=100% \
        --preview 'preview_file {}' \
        --input-label=" Type to search (filename-based) " \
        "${BASE_OPTIONS_FZF[@]}"
    ;;
  "🧠 Search by content")
    fzf --ansi --phony \
      --bind "start:reload-sync:echo" \
      --bind "change:reload:sleep 0.5; \
            [[ {q} != '' ]] && \
            rg -F --hidden --no-ignore --color=never \
               --count-matches \
               --with-filename \
               ${RG_EXCLUDES[*]} \
               {q} \"$SEARCH_DIR\" 2>/dev/null | \
            sed 's/:/\t(/' | sed 's/$/ matches)/' \
            || true" \
      --delimiter='\t' \
      --with-nth='1' \
      --preview "preview_content_file {1} {q}" \
      --input-label=" Type to search (content-based) " \
      "${BASE_OPTIONS_FZF[@]}"
    ;;
  "❌ Exit" | "")
    break
    ;;
  esac

done
