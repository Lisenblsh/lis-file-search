#!/usr/bin/env bash
SEARCH_DIR="$HOME"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMPTY_IMAGE="$SCRIPT_DIR/empty.png"

EXCLUDE_DIRS=(".git" "node_modules" ".cache" "/proc" "/run" "/tmp" "/var/cache")

FD_EXCLUDES=()
RG_EXCLUDES=()
for dir in "${EXCLUDE_DIRS[@]}"; do
  FD_EXCLUDES+=(--exclude "$dir")
  RG_EXCLUDES+=(--glob "!$dir")
done

# Функция для превью файлов
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

    kitty icat --clear --transfer-mode=memory --stdin=no "$EMPTY_IMAGE"
    echo -e "\033[1;35m🎥 Video file:\033[0m $file"
    echo -e "\033[1;33m📊 MIME type:\033[0m $mime_type"
    echo -e "\033[1;33m💾 Size:\033[0m $(stat -c%s "$file" 2>/dev/null | numfmt --to=iec || echo 'unknown')"
    ;;
  audio/*)
    kitty icat --clear --transfer-mode=memory --stdin=no "$EMPTY_IMAGE"
    echo -e "\033[1;34m🎵 Audio file:\033[0m $file"
    echo -e "\033[1;33m📊 MIME type:\033[0m $mime_type"
    echo -e "\033[1;33m💾 Size:\033[0m $(stat -c%s "$file" 2>/dev/null | numfmt --to=iec || echo 'unknown')"
    ;;
  application/pdf)
    kitty icat --clear --transfer-mode=memory --stdin=no "$EMPTY_IMAGE"
    echo -e "\033[1;31m📕 PDF doc:\033[0m $file"
    echo -e "\033[1;33m📊 MIME type:\033[0m $mime_type"
    echo -e "\033[1;33m💾 Size:\033[0m $(stat -c%s "$file" 2>/dev/null | numfmt --to=iec || echo 'unknown')"

    ;;
  text/* | application/json | application/xml | application/javascript | application/x-sh | application/x-shellscript)
    kitty icat --clear --transfer-mode=memory --stdin=no "$EMPTY_IMAGE"
    bat --color=always --style=numbers --line-range=:100 "$file" 2>/dev/null || head -n 100 "$file"
    ;;
  *)
    kitty icat --clear --transfer-mode=memory --stdin=no "$EMPTY_IMAGE"
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
    kitty --class editterm --config /dev/null -e bash -lc "nvim '$file'" 2>/dev/null &
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
    vlc "$file" &
    ;;
  *)
    echo "$file" | wl-copy -n
    notify-send "Path to file copy to clipboard" "$(basename "$file")" -i clipboard -t 1500
    echo "Path was copy to clipboard: $file" >&2
    ;;
  esac
}

# export func for childe-shell
export -f open_file
export -f preview_file

SHELL=$(which bash)
# Меню выбора режима
choice=$(printf "🔍 Search by file name\n🧠 Search by content" |
  fzf --prompt="Select mode > ")

case "$choice" in
"🔍 Search by file name")
  fd "" "$SEARCH_DIR" --type f --hidden --no-ignore "${FD_EXCLUDES[@]}" 2>/dev/null |
    fzf --ansi --height=100% \
      --preview 'preview_file {}' \
      --bind "enter:execute:open_file {}" \
      --prompt "filter > " \
      --preview-window=right:70% \
      --bind="focus:transform-preview-label:echo [ {} ]" \
      --bind="ctrl-p:toggle-preview+transform-preview-label:echo [ {} ]"
  ;;
"🧠 Search by content")
  query=$(
    echo "" | fzf --print-query \
      --prompt "🔍 Enter your search query here: " \
      --header="╭─ SEARCH BY CONTENT ────────────────────╮
│ Enter text and press \"Enter\" to search │
╰────────────────────────────────────────╯" \
      --border=rounded \
      --color='prompt:226,header:39'
  )

  query=$(echo "$query" | head -1)
  [ -z "$query" ] && exit 0

  rg --hidden --no-ignore --no-heading --line-number --color=always "${RG_EXCLUDES[@]}" "$query" "$SEARCH_DIR" 2>/dev/null |
    fzf --ansi \
      --delimiter : \
      --nth 3.. \
      --preview 'bat --color=always --highlight-line {2} {1}' \
      --bind "enter:execute:open_file {1}" \
      --prompt "filter > " \
      --preview-window=right:70% \
      --bind="focus:transform-preview-label:echo [ {1} ]" \
      --bind="ctrl-p:toggle-preview+transform-preview-label:echo [ {1} ]" \
      --bind 'ctrl-c:abort'
  ;;
esac
