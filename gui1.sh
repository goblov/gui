#!/bin/bash
# ============================================================
# Применение настроек XFCE ПОСЛЕ первого входа
# Запускать внутри XFCE сессии в терминале
# ============================================================
set -e
USER_HOME="$HOME"

echo_step() { echo -e "\n\033[1;35m=== $1 ===\033[0m"; }

# ─────────────────────────────────────────────────────────────
echo_step "1. Проверка и установка Catppuccin темы"
# ─────────────────────────────────────────────────────────────
mkdir -p "$USER_HOME/.themes"

if [ ! -d "$USER_HOME/.themes/Catppuccin-Mocha-Standard-Mauve-Dark" ]; then
    echo "Скачиваю тему..."
    wget -q "https://github.com/catppuccin/gtk/releases/download/v1.0.3/Catppuccin-Mocha-Standard-Mauve-Dark.zip" \
        -O /tmp/catppuccin-gtk.zip \
    && unzip -q /tmp/catppuccin-gtk.zip -d "$USER_HOME/.themes/" \
    && echo "✓ Тема скачана" \
    || {
        echo "⚠ Не удалось скачать с GitHub, пробую зеркало..."
        wget -q "https://github.com/catppuccin/gtk/releases/latest/download/Catppuccin-Mocha-Standard-Mauve-Dark.zip" \
            -O /tmp/catppuccin-gtk.zip \
        && unzip -q /tmp/catppuccin-gtk.zip -d "$USER_HOME/.themes/" \
        && echo "✓ Тема скачана (зеркало)" \
        || echo "✗ Тема не скачана — проверьте интернет"
    }
else
    echo "✓ Тема уже установлена"
fi

# ─────────────────────────────────────────────────────────────
echo_step "2. Применение темы через xfconf-query"
# ─────────────────────────────────────────────────────────────

# GTK тема и иконки
xfconf-query -c xsettings -p /Net/ThemeName -s "Catppuccin-Mocha-Standard-Mauve-Dark" --create -t string
xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark" --create -t string
xfconf-query -c xsettings -p /Gtk/CursorThemeName -s "Adwaita" --create -t string
xfconf-query -c xsettings -p /Gtk/FontName -s "Noto Sans 10" --create -t string

# Сглаживание шрифтов
xfconf-query -c xsettings -p /Xft/Antialias -s 1 --create -t int
xfconf-query -c xsettings -p /Xft/Hinting -s 1 --create -t int
xfconf-query -c xsettings -p /Xft/HintStyle -s "hintslight" --create -t string
xfconf-query -c xsettings -p /Xft/RGBA -s "rgb" --create -t string

echo "✓ Тема применена"

# ─────────────────────────────────────────────────────────────
echo_step "3. Настройка рабочего стола (тёмный фон, без иконок)"
# ─────────────────────────────────────────────────────────────

# Без иконок на рабочем столе
xfconf-query -c xfce4-desktop -p /desktop-icons/style -s 0 --create -t int

# Тёмный фон #1E1E2E (Catppuccin Mocha Base)
# Получаем имя монитора динамически
MONITOR=$(xrandr --query | grep " connected" | head -1 | awk '{print $1}')
echo "Монитор: $MONITOR"

for SCREEN_PATH in \
    "/backdrop/screen0/monitor${MONITOR}/workspace0" \
    "/backdrop/screen0/monitorVirtual-1/workspace0" \
    "/backdrop/screen0/monitor0/workspace0"
do
    xfconf-query -c xfce4-desktop -p "$SCREEN_PATH/color-style" -s 0 --create -t int 2>/dev/null || true
    xfconf-query -c xfce4-desktop -p "$SCREEN_PATH/image-style" -s 0 --create -t int 2>/dev/null || true
    xfconf-query -c xfce4-desktop -p "$SCREEN_PATH/rgba1" \
        --create -t double -t double -t double -t double \
        -s 0.117647 -s 0.117647 -s 0.180392 -s 1.0 2>/dev/null || true
done

# Перезапуск xfdesktop для применения фона
xfdesktop --reload 2>/dev/null || pkill xfdesktop; sleep 1; xfdesktop & disown
echo "✓ Рабочий стол настроен"

# ─────────────────────────────────────────────────────────────
echo_step "4. Настройка панели (верхняя, время + громкость + дата)"
# ─────────────────────────────────────────────────────────────

# Удаляем нижнюю панель (panel-2) если есть
xfconf-query -c xfce4-panel -p /panels -s "1" --create -t int 2>/dev/null || true

# Параметры верхней панели
xfconf-query -c xfce4-panel -p /panels/panel-1/position -s "p=6;x=0;y=0" --create -t string
xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 28 --create -t uint
xfconf-query -c xfce4-panel -p /panels/panel-1/length -s 100 --create -t uint
xfconf-query -c xfce4-panel -p /panels/panel-1/position-locked -s true --create -t bool
xfconf-query -c xfce4-panel -p /panels/panel-1/background-style -s 1 --create -t int
xfconf-query -c xfce4-panel -p /panels/panel-1/background-color \
    --create -t double -t double -t double -t double \
    -s 0.117647 -s 0.117647 -s 0.180392 -s 1.0 2>/dev/null || true

# Часы — только формат (меняем уже существующие плагины)
# Ищем ID плагина clock
CLOCK_ID=$(xfconf-query -c xfce4-panel -l | grep "plugin-" | grep -v "plugin-ids" | \
    while read LINE; do
        VAL=$(xfconf-query -c xfce4-panel -p "$LINE" 2>/dev/null)
        [ "$VAL" = "clock" ] && echo "${LINE##*/plugin-}" && break
    done 2>/dev/null | head -1)

if [ -n "$CLOCK_ID" ]; then
    xfconf-query -c xfce4-panel -p /plugins/plugin-${CLOCK_ID}/digital-format \
        -s "%H:%M  %d %B" --create -t string
    xfconf-query -c xfce4-panel -p /plugins/plugin-${CLOCK_ID}/mode \
        -s 2 --create -t uint
    echo "✓ Формат часов обновлён (плагин $CLOCK_ID)"
else
    echo "⚠ Плагин clock не найден, перезапустите панель вручную"
fi

# Перезапуск панели
xfce4-panel -r &
echo "✓ Панель перезапущена"

# ─────────────────────────────────────────────────────────────
echo_step "5. Горячие клавиши тайлинга"
# ─────────────────────────────────────────────────────────────
mkdir -p "$USER_HOME/.local/bin"

cat > "$USER_HOME/.local/bin/tile.sh" << 'TILE_EOF'
#!/bin/bash
DIRECTION="$1"
WIN_ID=$(xdotool getactivewindow 2>/dev/null) || exit 1
read SCREEN_W SCREEN_H <<< $(xdotool getdisplaygeometry)
PANEL_H=28
WORK_H=$((SCREEN_H - PANEL_H))
HW=$((SCREEN_W / 2))
HH=$((WORK_H / 2))

unmax() { wmctrl -ir "$WIN_ID" -b remove,maximized_vert,maximized_horz 2>/dev/null; sleep 0.05; }
move() { xdotool windowmove "$WIN_ID" "$1" "$2" && xdotool windowsize "$WIN_ID" "$3" "$4"; }

case "$DIRECTION" in
  left)        unmax; move 0         $PANEL_H        $HW        $WORK_H ;;
  right)       unmax; move $HW       $PANEL_H        $HW        $WORK_H ;;
  top)         unmax; move 0         $PANEL_H        $SCREEN_W  $HH     ;;
  bottom)      unmax; move 0         $((PANEL_H+HH)) $SCREEN_W  $HH     ;;
  topleft)     unmax; move 0         $PANEL_H        $HW        $HH     ;;
  topright)    unmax; move $HW       $PANEL_H        $HW        $HH     ;;
  bottomleft)  unmax; move 0         $((PANEL_H+HH)) $HW        $HH     ;;
  bottomright) unmax; move $HW       $((PANEL_H+HH)) $HW        $HH     ;;
  maximize)    wmctrl -ir "$WIN_ID" -b add,maximized_vert,maximized_horz ;;
  center)
    unmax
    W=$((SCREEN_W*2/3)); H=$((WORK_H*2/3))
    X=$(((SCREEN_W-W)/2)); Y=$((PANEL_H+(WORK_H-H)/2))
    move $X $Y $W $H ;;
  nextscreen)  wmctrl -ir "$WIN_ID" -e "0,-1,-1,-1,-1" ;;
  grow)
    unmax
    GEOM=$(xdotool getwindowgeometry --shell "$WIN_ID")
    eval "$GEOM"
    W=$((WIDTH+50)); H=$((HEIGHT+30))
    move $X $Y $W $H ;;
  shrink)
    unmax
    GEOM=$(xdotool getwindowgeometry --shell "$WIN_ID")
    eval "$GEOM"
    W=$((WIDTH-50)); H=$((HEIGHT-30))
    move $X $Y $W $H ;;
esac
TILE_EOF
chmod +x "$USER_HOME/.local/bin/tile.sh"

# PATH
grep -q '.local/bin' "$USER_HOME/.bashrc" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.bashrc"

TILE="$USER_HOME/.local/bin/tile.sh"
declare -A SHORTCUTS=(
  ["<Super>Left"]="left"
  ["<Super>Right"]="right"
  ["<Super>Up"]="top"
  ["<Super>Down"]="bottom"
  ["<Alt><Super>Left"]="topleft"
  ["<Alt><Super>Right"]="topright"
  ["<Ctrl><Alt>Left"]="bottomleft"
  ["<Ctrl><Alt>Right"]="bottomright"
  ["<Ctrl><Super>f"]="maximize"
  ["<Ctrl><Super>c"]="center"
  ["<Ctrl><Alt><Super>Right"]="nextscreen"
  ["<Ctrl><Alt>equal"]="grow"
  ["<Ctrl><Alt>minus"]="shrink"
)

for KEY in "${!SHORTCUTS[@]}"; do
  DIR="${SHORTCUTS[$KEY]}"
  xfconf-query -c xfce4-keyboard-shortcuts \
    -p "/commands/custom/$KEY" \
    -t string -s "$TILE $DIR" --create 2>/dev/null || true
done

# Super+Space — смена раскладки
xfconf-query -c xfce4-keyboard-shortcuts \
    -p "/commands/custom/<Super>space" \
    -t string -s "xfce4-keyboard-settings" --create 2>/dev/null || true

echo "✓ Горячие клавиши применены"

# ─────────────────────────────────────────────────────────────
echo_step "6. tmux конфиг (Catppuccin)"
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
tmux source-file "$USER_HOME/.tmux.conf" 2>/dev/null && echo "✓ tmux конфиг применён" || echo "✓ tmux конфиг сохранён"

# ─────────────────────────────────────────────────────────────
echo_step "7. Автозапуск Claude Code в tmux"
# ─────────────────────────────────────────────────────────────
cat > "$USER_HOME/.claude-autostart.sh" << 'CLAUDE_EOF'
#!/bin/bash
if ! tmux has-session -t claude 2>/dev/null; then
    tmux new-session -d -s claude -x 220 -y 50
    tmux send-keys -t claude "claude --dangerously-skip-permissions" Enter
fi
CLAUDE_EOF
chmod +x "$USER_HOME/.claude-autostart.sh"

mkdir -p "$USER_HOME/.config/autostart"
cat > "$USER_HOME/.config/autostart/claude-tmux.desktop" << DESK_EOF
[Desktop Entry]
Type=Application
Name=Claude Code (tmux)
Exec=xfce4-terminal --title="Claude Code" -e "bash -c '$USER_HOME/.claude-autostart.sh; tmux attach -t claude'"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
DESK_EOF

echo "✓ Автозапуск Claude настроен"

# ─────────────────────────────────────────────────────────────
echo_step "8. Настройка xfce4-terminal (Catppuccin)"
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
MiscDefaultGeometry=120x35
MiscMenubarDefault=FALSE
MiscToolbarDefault=FALSE
ScrollingBar=TERMINAL_SCROLLBAR_NONE
TERM_EOF
echo "✓ Терминал настроен"

# ─────────────────────────────────────────────────────────────
echo ""
echo -e "\033[1;32m╔══════════════════════════════════════════════════════════╗"
echo    "║           ВСЕ НАСТРОЙКИ ПРИМЕНЕНЫ!                      ║"
echo    "╠══════════════════════════════════════════════════════════╣"
echo    "║  ✓ Catppuccin Mocha Mauve GTK тема                      ║"
echo    "║  ✓ Papirus-Dark иконки                                  ║"
echo    "║  ✓ Тёмный рабочий стол без иконок (#1E1E2E)             ║"
echo    "║  ✓ Верхняя панель: меню | громкость | ЧЧ:ММ ДД Месяц   ║"
echo    "║  ✓ Горячие клавиши тайлинга (Super/Alt/Ctrl)            ║"
echo    "║  ✓ tmux Catppuccin конфиг                               ║"
echo    "║  ✓ Claude Code автозапуск в tmux при входе              ║"
echo    "║  ✓ xfce4-terminal Catppuccin цвета                      ║"
echo    "╠══════════════════════════════════════════════════════════╣"
echo    "║  Выйдите и войдите снова для полного применения          ║"
echo    "║  (или просто перезагрузитесь: sudo reboot)              ║"
echo -e "╚══════════════════════════════════════════════════════════╝\033[0m"
