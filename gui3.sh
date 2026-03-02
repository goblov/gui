#!/bin/bash
# ============================================================
# ФИКС настроек XFCE - запускать ВНУТРИ XFCE сессии
# ============================================================
USER_HOME="$HOME"
LOG="$USER_HOME/xfce-fix.log"
exec > >(tee -a "$LOG") 2>&1

ok()   { echo -e "\033[1;32m✓ $1\033[0m"; }
warn() { echo -e "\033[1;33m⚠ $1\033[0m"; }
step() { echo -e "\n\033[1;35m══ $1 ══\033[0m"; }

step "ДИАГНОСТИКА"
echo "Пользователь : $(whoami)"
echo "HOME         : $USER_HOME"
echo "DISPLAY      : ${DISPLAY:-не задан}"
echo "Сессия       : ${DESKTOP_SESSION:-неизвестна}"
echo "xfconf       : $(which xfconf-query 2>/dev/null || echo 'НЕ НАЙДЕН')"
xrandr --query 2>/dev/null | grep " connected" || echo "xrandr: нет данных"

# ─────────────────────────────────────────────────────────────
step "1. УСТАНОВКА CATPPUCCIN ТЕМЫ"
# ─────────────────────────────────────────────────────────────
mkdir -p "$USER_HOME/.themes"
THEME_DIR="$USER_HOME/.themes/Catppuccin-Mocha-Standard-Mauve-Dark"

if [ ! -d "$THEME_DIR" ]; then
    warn "Тема не найдена, скачиваю..."
    # Пробуем несколько вариантов URL
    URLS=(
        "https://github.com/catppuccin/gtk/releases/download/v1.0.3/Catppuccin-Mocha-Standard-Mauve-Dark.zip"
        "https://github.com/catppuccin/gtk/releases/download/v0.7.2/Catppuccin-Mocha-Mauve.zip"
    )
    for URL in "${URLS[@]}"; do
        echo "Пробую: $URL"
        wget -q --timeout=30 "$URL" -O /tmp/catppuccin.zip && break
    done

    if [ -f /tmp/catppuccin.zip ] && [ -s /tmp/catppuccin.zip ]; then
        unzip -q /tmp/catppuccin.zip -d "$USER_HOME/.themes/"
        # Переименовываем если имя папки отличается
        for DIR in "$USER_HOME/.themes/Catppuccin"*; do
            [ -d "$DIR" ] && echo "Найдена папка темы: $DIR"
        done
        ok "Тема распакована"
    else
        warn "Тема не скачалась — применю цвета через GTK напрямую"
        # Создаём минимальную тему вручную
        mkdir -p "$THEME_DIR/gtk-3.0"
        cat > "$THEME_DIR/gtk-3.0/gtk.css" << 'CSS_EOF'
* {
    background-color: #1e1e2e;
    color: #cdd6f4;
}
window, .window, headerbar, .titlebar {
    background-color: #181825;
    color: #cdd6f4;
}
button {
    background-color: #313244;
    color: #cdd6f4;
    border-color: #45475a;
}
button:hover {
    background-color: #45475a;
}
CSS_EOF
        # index.theme для GTK
        cat > "$THEME_DIR/index.theme" << 'IDX_EOF'
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=Catppuccin-Mocha-Standard-Mauve-Dark
Comment=Catppuccin Mocha GTK theme
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=Catppuccin-Mocha-Standard-Mauve-Dark
MetacityTheme=Catppuccin-Mocha-Standard-Mauve-Dark
IconTheme=Papirus-Dark
CursorTheme=Adwaita
ButtonLayout=close,minimize,maximize:
IDX_EOF
        ok "Минимальная тема создана вручную"
    fi
else
    ok "Тема уже установлена: $THEME_DIR"
fi

# Проверяем что тема есть
ACTUAL_THEME=$(ls "$USER_HOME/.themes/" | grep -i catppuccin | head -1)
echo "Используем тему: $ACTUAL_THEME"

# ─────────────────────────────────────────────────────────────
step "2. ПРИМЕНЕНИЕ ТЕМЫ GTK"
# ─────────────────────────────────────────────────────────────

# Через xfconf
xfconf-query -c xsettings -p /Net/ThemeName      -s "${ACTUAL_THEME:-Catppuccin-Mocha-Standard-Mauve-Dark}" --create -t string
xfconf-query -c xsettings -p /Net/IconThemeName  -s "Papirus-Dark" --create -t string
xfconf-query -c xsettings -p /Gtk/CursorThemeName -s "Adwaita" --create -t string
xfconf-query -c xsettings -p /Gtk/FontName       -s "Noto Sans 10" --create -t string
xfconf-query -c xsettings -p /Xft/Antialias      -s 1  --create -t int
xfconf-query -c xsettings -p /Xft/Hinting        -s 1  --create -t int
xfconf-query -c xsettings -p /Xft/HintStyle      -s "hintslight" --create -t string
xfconf-query -c xsettings -p /Xft/RGBA           -s "rgb" --create -t string

# Через gsettings тоже (на случай если GNOME-совместимые настройки)
gsettings set org.gnome.desktop.interface gtk-theme "${ACTUAL_THEME:-Catppuccin-Mocha-Standard-Mauve-Dark}" 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" 2>/dev/null || true

ok "GTK тема применена"

# ─────────────────────────────────────────────────────────────
step "3. РАБОЧИЙ СТОЛ — ТЁМНЫЙ ФОН, БЕЗ ИКОНОК"
# ─────────────────────────────────────────────────────────────

xfconf-query -c xfce4-desktop -p /desktop-icons/style -s 0 --create -t int

# Применяем фон для ВСЕХ возможных путей мониторов
MONITOR_NAME=$(xrandr --query 2>/dev/null | grep " connected" | head -1 | awk '{print $1}' || echo "Virtual-1")
echo "Монитор: $MONITOR_NAME"

PATHS=(
    "/backdrop/screen0/monitor${MONITOR_NAME}/workspace0"
    "/backdrop/screen0/monitorVirtual-1/workspace0"
    "/backdrop/screen0/monitorHDMI-1/workspace0"
    "/backdrop/screen0/monitorDP-1/workspace0"
    "/backdrop/screen0/monitor0/workspace0"
)
for P in "${PATHS[@]}"; do
    xfconf-query -c xfce4-desktop -p "$P/color-style"  -s 0 --create -t int    2>/dev/null || true
    xfconf-query -c xfce4-desktop -p "$P/image-style"  -s 0 --create -t int    2>/dev/null || true
    xfconf-query -c xfce4-desktop -p "$P/rgba1" \
        --create -t double -t double -t double -t double \
        -s 0.117647 -s 0.117647 -s 0.180392 -s 1.0 2>/dev/null || true
done

# Перезапуск xfdesktop
pkill -x xfdesktop 2>/dev/null || true
sleep 0.5
xfdesktop &
disown
ok "Рабочий стол применён"

# ─────────────────────────────────────────────────────────────
step "4. ПАНЕЛЬ — УБИРАЕМ НИЖНЮЮ, ОСТАВЛЯЕМ ТОЛЬКО ВЕРХНЮЮ"
# ─────────────────────────────────────────────────────────────

# Убираем нижнюю панель через xfconf
xfconf-query -c xfce4-panel -p /panels -t int -s 1 --create 2>/dev/null || \
xfconf-query -c xfce4-panel -p /panels --create -t array -t int -a 1 2>/dev/null || true

# Верхняя панель — позиция, размер, цвет
xfconf-query -c xfce4-panel -p /panels/panel-1/position       -s "p=6;x=0;y=0"  --create -t string
xfconf-query -c xfce4-panel -p /panels/panel-1/size           -s 28    --create -t uint
xfconf-query -c xfce4-panel -p /panels/panel-1/length         -s 100   --create -t uint
xfconf-query -c xfce4-panel -p /panels/panel-1/position-locked -s true --create -t bool
xfconf-query -c xfce4-panel -p /panels/panel-1/background-style -s 1   --create -t int
xfconf-query -c xfce4-panel -p /panels/panel-1/enter-opacity  -s 100   --create -t uint
xfconf-query -c xfce4-panel -p /panels/panel-1/leave-opacity  -s 100   --create -t uint
# Цвет панели #1E1E2E
xfconf-query -c xfce4-panel -p /panels/panel-1/background-color \
    --create -t double -t double -t double -t double \
    -s 0.117647 -s 0.117647 -s 0.180392 -s 1.0 2>/dev/null || true

# Ищем все clock плагины и меняем формат
ALL_PLUGINS=$(xfconf-query -c xfce4-panel -l 2>/dev/null | grep "^/plugins/plugin-[0-9]*/digital-format" || true)
if [ -z "$ALL_PLUGINS" ]; then
    # Ищем по типу
    xfconf-query -c xfce4-panel -l 2>/dev/null | grep "^/plugins/plugin-" | grep -v "/" | while read P; do
        VAL=$(xfconf-query -c xfce4-panel -p "$P" 2>/dev/null)
        if [ "$VAL" = "clock" ]; then
            ID=${P##*/plugin-}
            xfconf-query -c xfce4-panel -p "/plugins/plugin-${ID}/digital-format" \
                -s "%H:%M  %d %B" --create -t string 2>/dev/null || true
            xfconf-query -c xfce4-panel -p "/plugins/plugin-${ID}/mode" \
                -s 2 --create -t uint 2>/dev/null || true
            echo "  Обновлён clock плагин: $ID"
        fi
    done
fi

# Перезапуск панели
xfce4-panel --restart &
sleep 1
ok "Панель применена"

# ─────────────────────────────────────────────────────────────
step "5. АВТОЗАПУСК CLAUDE CODE В TMUX"
# ─────────────────────────────────────────────────────────────

# Скрипт запуска
cat > "$USER_HOME/.claude-autostart.sh" << 'CLAUDE_EOF'
#!/bin/bash
sleep 2  # ждём пока xfce4-terminal инициализируется
if ! tmux has-session -t claude 2>/dev/null; then
    tmux new-session -d -s claude -x 220 -y 50
    tmux send-keys -t claude "claude --dangerously-skip-permissions" Enter
fi
# Открываем терминал с tmux сессией
xfce4-terminal --title="Claude Code" \
    --geometry=160x40 \
    -e "bash -c 'tmux attach -t claude'" &
CLAUDE_EOF
chmod +x "$USER_HOME/.claude-autostart.sh"

# Desktop autostart
mkdir -p "$USER_HOME/.config/autostart"
cat > "$USER_HOME/.config/autostart/claude-tmux.desktop" << DESK_EOF
[Desktop Entry]
Type=Application
Name=Claude Code
Exec=bash -c 'sleep 3 && $USER_HOME/.claude-autostart.sh'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
DESK_EOF

ok "Автозапуск Claude настроен"

# Запустить прямо сейчас
"$USER_HOME/.claude-autostart.sh" &

# ─────────────────────────────────────────────────────────────
step "6. TMUX КОНФИГ"
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
tmux source-file "$USER_HOME/.tmux.conf" 2>/dev/null && ok "tmux конфиг применён" || ok "tmux конфиг сохранён"

# ─────────────────────────────────────────────────────────────
step "7. ГОРЯЧИЕ КЛАВИШИ ТАЙЛИНГА"
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
move()  { xdotool windowmove "$WIN_ID" "$1" "$2" && xdotool windowsize "$WIN_ID" "$3" "$4"; }

case "$DIRECTION" in
  left)        unmax; move 0    $PANEL_H        $HW       $WORK_H ;;
  right)       unmax; move $HW  $PANEL_H        $HW       $WORK_H ;;
  top)         unmax; move 0    $PANEL_H        $SCREEN_W $HH     ;;
  bottom)      unmax; move 0    $((PANEL_H+HH)) $SCREEN_W $HH     ;;
  topleft)     unmax; move 0    $PANEL_H        $HW       $HH     ;;
  topright)    unmax; move $HW  $PANEL_H        $HW       $HH     ;;
  bottomleft)  unmax; move 0    $((PANEL_H+HH)) $HW       $HH     ;;
  bottomright) unmax; move $HW  $((PANEL_H+HH)) $HW       $HH     ;;
  maximize)    wmctrl -ir "$WIN_ID" -b add,maximized_vert,maximized_horz ;;
  center)
    unmax
    W=$((SCREEN_W*2/3)); H=$((WORK_H*2/3))
    X=$(((SCREEN_W-W)/2)); Y=$((PANEL_H+(WORK_H-H)/2))
    move $X $Y $W $H ;;
  nextscreen)  wmctrl -ir "$WIN_ID" -e "0,-1,-1,-1,-1" ;;
  grow)
    GEOM=$(xdotool getwindowgeometry --shell "$WIN_ID"); eval "$GEOM"
    unmax; move $X $Y $((WIDTH+50)) $((HEIGHT+30)) ;;
  shrink)
    GEOM=$(xdotool getwindowgeometry --shell "$WIN_ID"); eval "$GEOM"
    unmax; move $X $Y $((WIDTH-50)) $((HEIGHT-30)) ;;
esac
TILE_EOF
chmod +x "$USER_HOME/.local/bin/tile.sh"

grep -q '.local/bin' "$USER_HOME/.bashrc" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.bashrc"

TILE="$USER_HOME/.local/bin/tile.sh"
declare -A SHORTCUTS=(
  ["<Super>Left"]="left"    ["<Super>Right"]="right"
  ["<Super>Up"]="top"       ["<Super>Down"]="bottom"
  ["<Alt><Super>Left"]="topleft"    ["<Alt><Super>Right"]="topright"
  ["<Ctrl><Alt>Left"]="bottomleft"  ["<Ctrl><Alt>Right"]="bottomright"
  ["<Ctrl><Super>f"]="maximize"     ["<Ctrl><Super>c"]="center"
  ["<Ctrl><Alt><Super>Right"]="nextscreen"
  ["<Ctrl><Alt>equal"]="grow"       ["<Ctrl><Alt>minus"]="shrink"
)
for KEY in "${!SHORTCUTS[@]}"; do
  DIR="${SHORTCUTS[$KEY]}"
  xfconf-query -c xfce4-keyboard-shortcuts \
    -p "/commands/custom/$KEY" -t string -s "$TILE $DIR" --create 2>/dev/null || true
done
xfconf-query -c xfce4-keyboard-shortcuts \
  -p "/commands/custom/<Super>space" -t string -s "xfce4-keyboard-settings" --create 2>/dev/null || true
ok "Горячие клавиши применены"

# ─────────────────────────────────────────────────────────────
step "8. XFCE4-TERMINAL CATPPUCCIN ЦВЕТА"
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
echo    "║           ГОТОВО! ЧТО СДЕЛАНО:                          ║"
echo    "╠══════════════════════════════════════════════════════════╣"
echo    "║  ✓ Catppuccin тема GTK (или минимальная, если нет сети) ║"
echo    "║  ✓ Тёмный рабочий стол #1E1E2E, без иконок              ║"
echo    "║  ✓ Убрана нижняя панель                                 ║"
echo    "║  ✓ Верхняя панель: тёмный фон, время + дата             ║"
echo    "║  ✓ Claude Code запущен в tmux сессии 'claude'           ║"
echo    "║  ✓ Автозапуск Claude при входе в сессию                 ║"
echo    "║  ✓ Горячие клавиши тайлинга (Super/Ctrl/Alt)            ║"
echo    "║  ✓ xfce4-terminal Catppuccin цвета                      ║"
echo    "╠══════════════════════════════════════════════════════════╣"
echo    "║  Лог сохранён в: ~/xfce-fix.log                         ║"
echo    "║  Для tmux: tmux attach -t claude                        ║"
echo    "║  Выйди и войди снова для полного применения             ║"
echo -e "╚══════════════════════════════════════════════════════════╝\033[0m"
