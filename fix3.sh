#!/bin/bash
# ============================================================
# Запускать БЕЗ su, от имени dino:
#   chmod +x fix3.sh && ./fix3.sh
# ============================================================

# Проверка что не root
if [ "$(id -u)" = "0" ]; then
    echo "❌ Запусти БЕЗ su / sudo, просто: ./fix3.sh"
    exit 1
fi

USER_HOME="$HOME"
export DISPLAY=":0"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

ok()   { echo -e "\033[1;32m✓ $1\033[0m"; }
warn() { echo -e "\033[1;33m⚠ $1\033[0m"; }
step() { echo -e "\n\033[1;35m══ $1 ══\033[0m"; }

step "ПРОВЕРКА"
echo "Пользователь : $(whoami) (uid=$(id -u))"
echo "DBUS         : $DBUS_SESSION_BUS_ADDRESS"
echo "DISPLAY      : $DISPLAY"
# тест xfconf
if xfconf-query -c xsettings -p /Net/ThemeName 2>&1 | grep -q "Failed"; then
    warn "xfconf не работает — проблема с dbus"
    exit 1
fi
ok "xfconf работает"

# ─────────────────────────────────────────────────────────────
step "1. ТЕМА CATPPUCCIN"
# ─────────────────────────────────────────────────────────────
THEME_DIR="$USER_HOME/.themes/Catppuccin-Mocha-Standard-Mauve-Dark"
if [ ! -d "$THEME_DIR" ]; then
    mkdir -p "$USER_HOME/.themes"
    wget -q "https://github.com/catppuccin/gtk/releases/download/v1.0.3/Catppuccin-Mocha-Standard-Mauve-Dark.zip" \
        -O /tmp/catppuccin.zip \
    && unzip -q /tmp/catppuccin.zip -d "$USER_HOME/.themes/" \
    && ok "Тема скачана" \
    || warn "Не удалось скачать тему"
else
    ok "Тема уже есть: $THEME_DIR"
fi

THEME_NAME=$(ls "$USER_HOME/.themes/" | grep -i catppuccin | head -1)
echo "Тема: $THEME_NAME"

xfconf-query -c xsettings -p /Net/ThemeName      -s "$THEME_NAME" --create -t string
xfconf-query -c xsettings -p /Net/IconThemeName  -s "Papirus-Dark" --create -t string
xfconf-query -c xsettings -p /Gtk/FontName       -s "Noto Sans 10" --create -t string
xfconf-query -c xsettings -p /Xft/Antialias      -s 1  --create -t int
xfconf-query -c xsettings -p /Xft/Hinting        -s 1  --create -t int
xfconf-query -c xsettings -p /Xft/HintStyle      -s "hintslight" --create -t string
xfconf-query -c xsettings -p /Xft/RGBA           -s "rgb" --create -t string
ok "Тема применена"

# ─────────────────────────────────────────────────────────────
step "2. РАБОЧИЙ СТОЛ — ТЁМНЫЙ ФОН, БЕЗ ИКОНОК"
# ─────────────────────────────────────────────────────────────
xfconf-query -c xfce4-desktop -p /desktop-icons/style -s 0 --create -t int

# Узнаём все пути backdrop из текущего конфига
echo "Текущие пути backdrop:"
xfconf-query -c xfce4-desktop -l 2>/dev/null | grep "workspace0$" || echo "  (нет)"

# Применяем для всех возможных имён мониторов
for MON in Virtual-1 HDMI-1 DP-1 eDP-1 VIRT-1 0; do
    P="/backdrop/screen0/monitor${MON}/workspace0"
    xfconf-query -c xfce4-desktop -p "$P/color-style"  -s 0 --create -t int    2>/dev/null
    xfconf-query -c xfce4-desktop -p "$P/image-style"  -s 0 --create -t int    2>/dev/null
    xfconf-query -c xfce4-desktop -p "$P/rgba1" \
        --create -t double -t double -t double -t double \
        -s 0.117647 -s 0.117647 -s 0.180392 -s 1.0 2>/dev/null
done

# Ещё раз узнаём реальные пути и применяем явно
xfconf-query -c xfce4-desktop -l 2>/dev/null | grep "workspace0/rgba1" | while read P; do
    BASE="${P%/rgba1}"
    xfconf-query -c xfce4-desktop -p "$BASE/color-style" -s 0 -t int  2>/dev/null
    xfconf-query -c xfce4-desktop -p "$BASE/image-style" -s 0 -t int  2>/dev/null
    xfconf-query -c xfce4-desktop -p "$BASE/rgba1" \
        -t double -t double -t double -t double \
        -s 0.117647 -s 0.117647 -s 0.180392 -s 1.0 2>/dev/null
    echo "  → применён фон: $BASE"
done

pkill -x xfdesktop 2>/dev/null; sleep 0.5; xfdesktop &
ok "Рабочий стол применён"

# ─────────────────────────────────────────────────────────────
step "3. ПАНЕЛЬ — УБИРАЕМ НИЖНЮЮ"
# ─────────────────────────────────────────────────────────────
echo "Текущие панели:"
xfconf-query -c xfce4-panel -p /panels 2>&1

# Устанавливаем только панель 1
xfconf-query -c xfce4-panel -p /panels -t int -s 1 2>/dev/null || \
    xfconf-query -c xfce4-panel -p /panels --create -t int -s 1 2>/dev/null || true

# Верхняя позиция
xfconf-query -c xfce4-panel -p /panels/panel-1/position -s "p=6;x=0;y=0" --create -t string
xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 28 --create -t uint
xfconf-query -c xfce4-panel -p /panels/panel-1/length -s 100 --create -t uint
xfconf-query -c xfce4-panel -p /panels/panel-1/position-locked -s true --create -t bool

# Цвет панели
xfconf-query -c xfce4-panel -p /panels/panel-1/background-style -s 1 --create -t int
xfconf-query -c xfce4-panel -p /panels/panel-1/background-color \
    --create -t double -t double -t double -t double \
    -s 0.117647 -s 0.117647 -s 0.180392 -s 1.0 2>/dev/null

# Обновляем часы: ищем ID плагина clock
echo "Плагины панели:"
xfconf-query -c xfce4-panel -l 2>/dev/null | grep "^/plugins/plugin-[0-9]*$" | while read P; do
    VAL=$(xfconf-query -c xfce4-panel -p "$P" 2>/dev/null)
    echo "  $P = $VAL"
    if [ "$VAL" = "clock" ]; then
        ID=$(echo "$P" | grep -o '[0-9]*')
        xfconf-query -c xfce4-panel -p "/plugins/plugin-${ID}/digital-format" \
            -s "%H:%M  %d %B" --create -t string
        xfconf-query -c xfce4-panel -p "/plugins/plugin-${ID}/mode" \
            -s 2 --create -t uint
        echo "  → Обновлён clock ID=$ID"
    fi
done

xfce4-panel --restart &
sleep 1
ok "Панель обновлена"

# ─────────────────────────────────────────────────────────────
step "4. TMUX КОНФИГ"
# ─────────────────────────────────────────────────────────────
cat > "$USER_HOME/.tmux.conf" << 'TMUX_EOF'
set -g mouse on
set -g status-right ""
set -g default-terminal "screen-256color"
set -g history-limit 10000
set -g base-index 1
set -g status-style bg=black,fg='#A88CCA'
setw -g window-status-current-style bg=black,fg='#A88CCA',bold
set -g mode-style bg='#A88CCA',fg=black
set -g pane-border-style fg='#313244'
set -g pane-active-border-style fg='#A88CCA'
bind -n C-Space new-window
bind -n C-n command-prompt "rename-window '%%'"
TMUX_EOF
tmux source-file "$USER_HOME/.tmux.conf" 2>/dev/null || true
ok "tmux конфиг применён"

# ─────────────────────────────────────────────────────────────
step "5. АВТОЗАПУСК CLAUDE CODE В TMUX"
# ─────────────────────────────────────────────────────────────
cat > "$USER_HOME/.claude-autostart.sh" << 'CLAUDE_EOF'
#!/bin/bash
sleep 3
if ! tmux has-session -t claude 2>/dev/null; then
    tmux new-session -d -s claude -x 200 -y 50
    tmux send-keys -t claude "claude --dangerously-skip-permissions" Enter
fi
xfce4-terminal --title="Claude Code" --geometry=160x40 \
    --command="bash -c 'tmux attach -t claude'"
CLAUDE_EOF
chmod +x "$USER_HOME/.claude-autostart.sh"

mkdir -p "$USER_HOME/.config/autostart"
cat > "$USER_HOME/.config/autostart/claude-tmux.desktop" << DESK_EOF
[Desktop Entry]
Type=Application
Name=Claude Code
Exec=$USER_HOME/.claude-autostart.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
DESK_EOF
ok "Автозапуск настроен"

# ─────────────────────────────────────────────────────────────
step "6. ГОРЯЧИЕ КЛАВИШИ ТАЙЛИНГА"
# ─────────────────────────────────────────────────────────────
mkdir -p "$USER_HOME/.local/bin"
cat > "$USER_HOME/.local/bin/tile.sh" << 'TILE_EOF'
#!/bin/bash
DIRECTION="$1"
WIN_ID=$(xdotool getactivewindow 2>/dev/null) || exit 1
read SCREEN_W SCREEN_H <<< $(xdotool getdisplaygeometry)
PANEL_H=28; WORK_H=$((SCREEN_H-PANEL_H))
HW=$((SCREEN_W/2)); HH=$((WORK_H/2))
unmax() { wmctrl -ir "$WIN_ID" -b remove,maximized_vert,maximized_horz 2>/dev/null; sleep 0.05; }
move()  { xdotool windowmove "$WIN_ID" "$1" "$2" && xdotool windowsize "$WIN_ID" "$3" "$4"; }
case "$DIRECTION" in
  left)        unmax; move 0   $PANEL_H       $HW       $WORK_H ;;
  right)       unmax; move $HW $PANEL_H       $HW       $WORK_H ;;
  top)         unmax; move 0   $PANEL_H       $SCREEN_W $HH     ;;
  bottom)      unmax; move 0   $((PANEL_H+HH)) $SCREEN_W $HH   ;;
  topleft)     unmax; move 0   $PANEL_H       $HW       $HH     ;;
  topright)    unmax; move $HW $PANEL_H       $HW       $HH     ;;
  bottomleft)  unmax; move 0   $((PANEL_H+HH)) $HW      $HH    ;;
  bottomright) unmax; move $HW $((PANEL_H+HH)) $HW      $HH    ;;
  maximize)    wmctrl -ir "$WIN_ID" -b add,maximized_vert,maximized_horz ;;
  center)      unmax; W=$((SCREEN_W*2/3)); H=$((WORK_H*2/3))
               move $(((SCREEN_W-W)/2)) $((PANEL_H+(WORK_H-H)/2)) $W $H ;;
  grow)        GEOM=$(xdotool getwindowgeometry --shell "$WIN_ID"); eval "$GEOM"
               unmax; move $X $Y $((WIDTH+50)) $((HEIGHT+30)) ;;
  shrink)      GEOM=$(xdotool getwindowgeometry --shell "$WIN_ID"); eval "$GEOM"
               unmax; move $X $Y $((WIDTH-50)) $((HEIGHT-30)) ;;
esac
TILE_EOF
chmod +x "$USER_HOME/.local/bin/tile.sh"
grep -q '.local/bin' "$USER_HOME/.bashrc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.bashrc"

TILE="$USER_HOME/.local/bin/tile.sh"
declare -A KS=(
  ["<Super>Left"]="left"   ["<Super>Right"]="right"
  ["<Super>Up"]="top"      ["<Super>Down"]="bottom"
  ["<Alt><Super>Left"]="topleft"   ["<Alt><Super>Right"]="topright"
  ["<Ctrl><Alt>Left"]="bottomleft" ["<Ctrl><Alt>Right"]="bottomright"
  ["<Ctrl><Super>f"]="maximize"    ["<Ctrl><Super>c"]="center"
  ["<Ctrl><Alt>equal"]="grow"      ["<Ctrl><Alt>minus"]="shrink"
)
for KEY in "${!KS[@]}"; do
  xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$KEY" \
    -t string -s "$TILE ${KS[$KEY]}" --create 2>/dev/null || true
done
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>space" \
    -t string -s "xfce4-keyboard-settings" --create 2>/dev/null || true
ok "Горячие клавиши применены"

# ─────────────────────────────────────────────────────────────
step "7. TERMINAL CATPPUCCIN"
# ─────────────────────────────────────────────────────────────
mkdir -p "$USER_HOME/.config/xfce4/terminal"
cat > "$USER_HOME/.config/xfce4/terminal/terminalrc" << 'TERM_EOF'
[Configuration]
FontName=Monospace 11
ColorForeground=#CDD6F4
ColorBackground=#1E1E2E
ColorCursor=#F5E0DC
ColorPalette=#45475A;#F38BA8;#A6E3A1;#F9E2AF;#89B4FA;#F5C2E7;#94E2D5;#BAC2DE;#585B70;#F38BA8;#A6E3A1;#F9E2AF;#89B4FA;#F5C2E7;#94E2D5;#A6ADC8
MiscAlwaysShowTabs=FALSE
MiscBell=FALSE
MiscDefaultGeometry=160x40
MiscMenubarDefault=FALSE
MiscToolbarDefault=FALSE
ScrollingBar=TERMINAL_SCROLLBAR_NONE
TERM_EOF
ok "Терминал настроен"

# ─────────────────────────────────────────────────────────────
echo ""
echo -e "\033[1;32m╔══════════════════════════════════════════════════════════╗"
echo    "║  ГОТОВО! Выйди из сессии и войди снова.                  ║"
echo    "║  (Applications → Log Out → Log Out)                     ║"
echo -e "╚══════════════════════════════════════════════════════════╝\033[0m"
