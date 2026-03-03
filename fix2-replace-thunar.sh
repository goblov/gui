#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
log()  { echo -e "${CYAN}▶ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }

DIR="$HOME/.filetree"
ELECTRON_BIN="$DIR/node_modules/.bin/electron"
VITE_BIN="$DIR/node_modules/.bin/vite"
WRAPPER="$HOME/.local/bin/filetree"

[ -f "$ELECTRON_BIN" ] || fail "Electron не найден. Запусти сначала filemanager.sh"

log "Пересборка интерфейса (после патча main.js)..."
rm -rf "$DIR/dist"
cd "$DIR"
"$VITE_BIN" build --logLevel warn || fail "Ошибка сборки"
ok "Пересборка завершена"

log "Обновление wrapper (передача пути от XFCE)..."
mkdir -p "$HOME/.local/bin"
cat > "$WRAPPER" << WRAP
#!/bin/bash
export DISPLAY="\${DISPLAY:-:0}"
if [ -n "\$1" ] && [ -d "\$1" ]; then
  exec "$ELECTRON_BIN" "$DIR" --no-sandbox "\$1"
else
  exec "$ELECTRON_BIN" "$DIR" --no-sandbox
fi
WRAP
chmod +x "$WRAPPER"
ok "Wrapper обновлён"

log "Отключение Thunar-демона..."
pkill -9 -f "thunar" 2>/dev/null || true
pkill -9 -f "Thunar" 2>/dev/null || true
sleep 0.3

mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/thunar.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Thunar
Hidden=true
X-GNOME-Autostart-enabled=false
EOF
for f in /etc/xdg/autostart/thunar*.desktop /etc/xdg/autostart/Thunar*.desktop; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  cp "$f" "$HOME/.config/autostart/$base"
  echo "Hidden=true" >> "$HOME/.config/autostart/$base"
done
ok "Thunar-демон заблокирован"

log "Регистрация XFCE helper..."
HELPERS_DIR="$HOME/.local/share/xfce4/helpers"
mkdir -p "$HELPERS_DIR"
cat > "$HELPERS_DIR/filetree.desktop" << EOF
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
EOF
ok "XFCE helper: $HELPERS_DIR/filetree.desktop"

mkdir -p "$HOME/.config/xfce4"
HELPERS_RC="$HOME/.config/xfce4/helpers.rc"
[ -f "$HELPERS_RC" ] && sed -i '/^FileManager=/d' "$HELPERS_RC"
echo "FileManager=filetree" >> "$HELPERS_RC"
ok "helpers.rc: FileManager=filetree"

log "Обновление mimeapps.list..."
MIMEAPPS="$HOME/.config/mimeapps.list"
for mime in "inode/directory" "x-directory/normal"; do
  sed -i "/^${mime//\//\\/}=/d" "$MIMEAPPS" 2>/dev/null || true
done
grep -q "^\[Default Applications\]" "$MIMEAPPS" 2>/dev/null || echo "[Default Applications]" > "$MIMEAPPS"
sed -i '/^\[Default Applications\]/a inode\/directory=filetree.desktop\nx-directory\/normal=filetree.desktop' "$MIMEAPPS"
ok "mimeapps.list обновлён"

command -v xdg-mime &>/dev/null && xdg-mime default filetree.desktop inode/directory 2>/dev/null || true
command -v gio &>/dev/null && gio mime inode/directory filetree.desktop 2>/dev/null && ok "gio mime: filetree" || true

log "Настройка xfconf..."
if command -v xfconf-query &>/dev/null; then
  xfconf-query -c xfce4-mime-settings -p /FileManager -n -t string -s "$WRAPPER" 2>/dev/null \
    || xfconf-query -c xfce4-mime-settings -p /FileManager -s "$WRAPPER" 2>/dev/null || true
  ok "xfconf обновлён"
else
  XFCE_XML="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-mime-settings.xml"
  mkdir -p "$(dirname $XFCE_XML)"
  cat > "$XFCE_XML" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-mime-settings" version="1.0">
  <property name="FileManager" type="string" value="$WRAPPER"/>
</channel>
EOF
  ok "xfce4-mime-settings.xml записан"
fi

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
xfdesktop --reload 2>/dev/null || true

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Готово! Сделай re-login:${NC}"
echo -e "  ${CYAN}xfce4-session-logout${NC}"
echo ""
echo -e "  После входа: двойной клик на папке → FileTree"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
