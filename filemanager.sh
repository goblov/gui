#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
log()  { echo -e "${CYAN}▶ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }

WRAPPER="$HOME/.local/bin/filetree"

if [ ! -f "$WRAPPER" ]; then
  echo -e "${RED}✗ Wrapper не найден: $WRAPPER${NC}"
  echo "  Сначала запусти основной скрипт filemanager.sh"
  exit 1
fi

# ─── 1. XFCE Helper-файл — главный механизм XFCE ─────────────────────
# XFCE игнорирует xdg-mime и читает менеджер файлов только отсюда
log "Создание XFCE helper-файла..."
HELPERS_DIR="$HOME/.local/share/xfce4/helpers"
mkdir -p "$HELPERS_DIR"

cat > "$HELPERS_DIR/filetree.desktop" << HELPER
[Desktop Entry]
Version=1.0
Encoding=UTF-8
Type=X-XFCE-Helper
X-XFCE-Helper-Name=FileTree
X-XFCE-Helper-Category=FileManager
X-XFCE-Binaries=$WRAPPER;
X-XFCE-Commands=$WRAPPER;
X-XFCE-CommandsWithParameter=$WRAPPER "%s";
Icon=system-file-manager
Name=FileTree
Comment=Custom file manager
HELPER
ok "XFCE helper: $HELPERS_DIR/filetree.desktop"

# ─── 2. helpers.rc ────────────────────────────────────────────────────
log "Обновление helpers.rc..."
HELPERS_RC="$HOME/.config/xfce4/helpers.rc"
mkdir -p "$HOME/.config/xfce4"
[ -f "$HELPERS_RC" ] && sed -i '/^FileManager=/d' "$HELPERS_RC"
echo "FileManager=filetree" >> "$HELPERS_RC"
ok "helpers.rc: FileManager=filetree"

# ─── 3. xfconf-query ─────────────────────────────────────────────────
log "Запись в xfconf..."
if command -v xfconf-query &>/dev/null; then
  xfconf-query -c xfce4-mime-settings -p /FileManager -n -t string -s "$WRAPPER" 2>/dev/null \
    || xfconf-query -c xfce4-mime-settings -p /FileManager -s "$WRAPPER" 2>/dev/null || true
  xfconf-query -c xfce4-session -p /general/FileManager -n -t string -s "$WRAPPER" 2>/dev/null \
    || xfconf-query -c xfce4-session -p /general/FileManager -s "$WRAPPER" 2>/dev/null || true
  ok "xfconf записан"
else
  warn "xfconf-query не найден"
fi

# ─── 4. Проверка exo-open ─────────────────────────────────────────────
if command -v exo-open &>/dev/null; then
  log "Тест exo-open..."
  RESULT=$(exo-open --query FileManager 2>/dev/null || echo "")
  if echo "$RESULT" | grep -qi "filetree"; then
    ok "exo-open видит filetree"
  else
    warn "exo-open показывает: $RESULT  (изменится после re-login)"
  fi
fi

# ─── 5. mimeapps.list ────────────────────────────────────────────────
log "Перезапись mimeapps.list..."
MIMEAPPS="$HOME/.config/mimeapps.list"
sed -i '/^inode\/directory=/d;/^x-directory\/normal=/d;/^x-directory\/gnome-default-handler=/d' "$MIMEAPPS" 2>/dev/null || true
grep -q "^\[Default Applications\]" "$MIMEAPPS" 2>/dev/null || echo "[Default Applications]" > "$MIMEAPPS"
sed -i '/^\[Default Applications\]/a inode\/directory=filetree.desktop\nx-directory\/normal=filetree.desktop' "$MIMEAPPS"
grep -q "^\[Added Associations\]" "$MIMEAPPS" 2>/dev/null || printf '\n[Added Associations]\n' >> "$MIMEAPPS"
sed -i '/^\[Added Associations\]/a inode\/directory=filetree.desktop;\nx-directory\/normal=filetree.desktop;' "$MIMEAPPS"
ok "mimeapps.list обновлён"

# ─── 6. gio + xdg-mime ───────────────────────────────────────────────
log "Обновление gio/xdg..."
command -v gio &>/dev/null && gio mime inode/directory filetree.desktop 2>/dev/null && ok "gio mime обновлён" || true
command -v xdg-mime &>/dev/null && xdg-mime default filetree.desktop inode/directory 2>/dev/null && ok "xdg-mime обновлён" || true

# ─── 7. Убить Thunar-демон, перезапустить XFCE ───────────────────────
log "Перезапуск XFCE-компонентов..."
pkill -f "thunar" 2>/dev/null; pkill -f "Thunar" 2>/dev/null || true
sleep 0.5
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
xfdesktop --reload 2>/dev/null || true
ok "XFCE перезапущен"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Готово!${NC}"
echo ""
echo -e "  Проверка: ${CYAN}exo-open --launch FileManager${NC}"
echo -e "  или дважды кликни на папке на рабочем столе"
echo ""
echo -e "${YELLOW}  Если Thunar всё ещё открывается:${NC}"
echo -e "${YELLOW}  выйди из системы и войди снова (re-login)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
