#!/usr/bin/env bash
# Russian UI for the official ZCode Desktop AppImage on Linux.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HOME}/.local/share/ZCode/squashfs-root"
SHARE="${HOME}/.local/share/ZCode"
MARKER_NAME=".zcode-ru-linux"

die() { printf 'Ошибка: %s\n' "$*" >&2; exit 1; }

need_node() {
  command -v node >/dev/null 2>&1 || die "Нужен Node.js 18 или новее. Установите nodejs и запустите скрипт снова."
  local major
  major="$(node -p 'process.versions.node.split(".")[0]')"
  [[ "$major" -ge 18 ]] || die "Node.js слишком старый ($(node -v)). Нужен 18+."
}

is_appimage() {
  [[ -f "$1" ]] || return 1
  local base
  base="$(basename "$1")"
  [[ "$base" == *.AppImage || "$base" == *.appimage ]] && return 0
  [[ -x "$1" ]] && "$1" --appimage-offset >/dev/null 2>&1
}

find_appimage() {
  local dir hit
  for dir in \
    "${SHARE}" \
    "${HOME}/Загрузки" \
    "${HOME}/Downloads" \
    "${HOME}/Desktop" \
    "${HOME}/Рабочий стол"
  do
    [[ -d "$dir" ]] || continue
    hit="$(set +o pipefail; find "$dir" -maxdepth 2 -type f -name 'ZCode*.AppImage' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || true)"
    if [[ -n "$hit" ]]; then
      printf '%s\n' "$hit"
      return 0
    fi
  done
  return 1
}

extract_appimage() {
  local image="$1"
  command -v fusermount >/dev/null 2>&1 || command -v fusermount3 >/dev/null 2>&1 || true
  local work
  work="$(mktemp -d)"
  if ! (cd "$work" && "$image" --appimage-extract >/dev/null); then
    rm -rf "$work"
    die "Не удалось распаковать AppImage. На Ubuntu поставьте пакет libfuse2t64 и повторите."
  fi
  [[ -d "$work/squashfs-root" ]] || { rm -rf "$work"; die "В AppImage нет squashfs-root."; }
  rm -rf "$DEST"
  mkdir -p "$SHARE"
  mv "$work/squashfs-root" "$DEST"
  rm -rf "$work"
  chmod +x "$DEST/zcode" "$DEST/AppRun" 2>/dev/null || true
}

stop_zcode() {
  if pgrep -f "${DEST}/zcode" >/dev/null 2>&1; then
    pkill -f "${DEST}/zcode" || true
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
      pgrep -f "${DEST}/zcode" >/dev/null 2>&1 || return 0
      sleep 0.3
    done
    pkill -9 -f "${DEST}/zcode" || true
  fi
}

sandbox_ready() {
  [[ -u "${DEST}/chrome-sandbox" ]]
}

userns_restricted() {
  [[ "$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || echo 0)" == "1" ]]
}

write_desktop() {
  local exec_line bin="$DEST/zcode"
  if sandbox_ready || ! userns_restricted; then
    exec_line="\"${bin}\" %U"
  else
    exec_line="\"${bin}\" --no-sandbox %U"
  fi
  mkdir -p "${HOME}/.local/share/applications"
  cat > "${HOME}/.local/share/applications/zcode.desktop" << EOF
[Desktop Entry]
Name=ZCode
Comment=ZCode Desktop App
Exec=${exec_line}
Terminal=false
Type=Application
Icon=zcode
Categories=Development;
MimeType=x-scheme-handler/zcode;
StartupWMClass=ZCode
EOF
  chmod 755 "${HOME}/.local/share/applications/zcode.desktop"
  if [[ -f "${DEST}/zcode.png" ]]; then
    mkdir -p "${HOME}/.local/share/icons/hicolor/1024x1024/apps"
    cp -f "${DEST}/zcode.png" "${HOME}/.local/share/icons/hicolor/1024x1024/apps/zcode.png"
    gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi
  update-desktop-database "${HOME}/.local/share/applications" >/dev/null 2>&1 || true
  mkdir -p "${HOME}/.local/bin"
  ln -sfn "$bin" "${HOME}/.local/bin/zcode"
  local desktop_dir file
  desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
  for file in \
    "${desktop_dir}/zcode.desktop" \
    "${HOME}/Desktop/zcode.desktop" \
    "${HOME}/Рабочий стол/zcode.desktop"
  do
    [[ -n "$file" && -f "$file" ]] || continue
    cp -f "${HOME}/.local/share/applications/zcode.desktop" "$file"
    chmod 755 "$file"
    gio set "$file" metadata::trusted true >/dev/null 2>&1 || true
  done
}

set_locale() {
  node << 'JS'
const fs = require('fs');
const path = require('path');
const os = require('os');
const file = path.join(os.homedir(), '.zcode/v2/setting.json');
if (!fs.existsSync(file)) process.exit(0);
const data = JSON.parse(fs.readFileSync(file, 'utf8'));
data.locale = 'zh-CN';
data.localePreference = 'zh-CN';
const raw = fs.readFileSync(file, 'utf8');
const pretty = raw.includes('\n');
const text = pretty ? JSON.stringify(data, null, 2) : JSON.stringify(data);
fs.writeFileSync(file, text + (raw.endsWith('\n') ? '\n' : ''));
JS
}

uninstall() {
  [[ -f "${DEST}/resources/app.asar.ru-orig" ]] || die "Нет сохранённого оригинала ${DEST}/resources/app.asar.ru-orig. Удалять ZCode целиком этот скрипт не будет."
  stop_zcode
  cp -f "${DEST}/resources/app.asar.ru-orig" "${DEST}/resources/app.asar"
  rm -f "${DEST}/resources/${MARKER_NAME}"
  printf 'Оригинальный интерфейс восстановлен. Запустите ZCode снова.\n'
}

install_from() {
  local target="${1:-}"
  need_node
  mkdir -p "$SHARE"
  if [[ -n "$target" ]]; then
    if is_appimage "$target"; then
      if [[ ! -x "${DEST}/zcode" ]]; then
        printf 'Распаковка %s\n' "$target"
        extract_appimage "$target"
      fi
    elif [[ -f "${target}/resources/app.asar" ]]; then
      DEST="$(cd "$target" && pwd)"
    elif [[ -f "${target}/app.asar" ]]; then
      die "Укажите каталог ZCode, а не сам app.asar. Рядом должен быть файл zcode."
    else
      die "Не понял путь: ${target}. Нужен AppImage или каталог с resources/app.asar."
    fi
  elif [[ ! -x "${DEST}/zcode" ]]; then
    local image
    image="$(find_appimage)" || die "ZCode не найден. Укажите AppImage: ./install.sh ~/Загрузки/ZCode-*-linux-x64.AppImage"
    printf 'Распаковка %s\n' "$image"
    extract_appimage "$image"
  fi

  [[ -f "${DEST}/resources/app.asar" ]] || die "Нет ${DEST}/resources/app.asar"
  stop_zcode
  if [[ ! -f "${DEST}/resources/app.asar.ru-orig" ]]; then
    cp -f "${DEST}/resources/app.asar" "${DEST}/resources/app.asar.ru-orig"
    printf 'Сохранена копия исходного app.asar\n'
  fi
  node "${ROOT}/russify.js" "$DEST"
  printf 'zcode-ru-linux\n' > "${DEST}/resources/${MARKER_NAME}"
  set_locale
  write_desktop
  printf 'Готово. Английский язык снова английский. Русский стоит на месте китайского и в списке называется «Русский».\n'
  if ! sandbox_ready && userns_restricted; then
    printf 'Песочница Electron на этой системе закрыта. Ярлык запускает ZCode с --no-sandbox.\n'
    printf 'Чтобы убрать этот флаг: sudo chown root:root "%s/chrome-sandbox" && sudo chmod 4755 "%s/chrome-sandbox"\n' "$DEST" "$DEST"
  fi
  if [[ -n "${WAYLAND_DISPLAY:-${DISPLAY:-}}" ]]; then
    if sandbox_ready || ! userns_restricted; then
      "$DEST/zcode" >/dev/null 2>&1 &
    else
      "$DEST/zcode" --no-sandbox >/dev/null 2>&1 &
    fi
    printf 'ZCode запущен.\n'
  fi
}

case "${1:-}" in
  -h|--help)
    cat << 'EOF'
Использование:
  ./install.sh [AppImage или каталог ZCode]
  ./install.sh --uninstall

Без аргумента ищет распакованную копию в ~/.local/share/ZCode/squashfs-root,
затем AppImage в ~/.local/share/ZCode, «Загрузках» и Downloads.
EOF
    ;;
  --uninstall)
    uninstall
    ;;
  *)
    install_from "${1:-}"
    ;;
esac
