#!/bin/bash
# ============================================================
# Полная настройка Debian 13 (netinst, ARM)
# 1. Claude Code в tmux (dangerously-skip-permissions)
# 2. XFCE4 GUI (Catppuccin тема, Openbox, панель, тайлинг)
# ============================================================
set -e

CURRENT_USER="$(whoami)"
USER_HOME="$HOME"

echo_step() { echo -e "\n\033[1;35m=== $1 ===\033[0m"; }

# ─────────────────────────────────────────────────────────────
echo_step "1. Обновление системы"
# ─────────────────────────────────────────────────────────────
sudo apt update && sudo apt upgrade -y

# ─────────────────────────────────────────────────────────────
echo_step "2. Установка XFCE4 + Openbox + зависимости"
# ─────────────────────────────────────────────────────────────
sudo apt install -y \
  xfce4 xfce4-goodies \
  openbox obconf \
  lightdm lightdm-gtk-greeter \
  xfce4-terminal \
  tmux curl wget git unzip \
  wmctrl xdotool \
  pulseaudio pavucontrol \
  fonts-noto fonts-noto-color-emoji \
  gtk2-engines-murrine gtk2-engines-pixbuf \
  papirus-icon-theme \
  xfce4-whiskermenu-plugin \
  xfce4-clipman-plugin \
  dbus-x11

# ─────────────────────────────────────────────────────────────
echo_step "3. Установка Node.js LTS"
# ─────────────────────────────────────────────────────────────
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
node --version && npm --version

# ─────────────────────────────────────────────────────────────
echo_step "4. Установка Claude Code"
# ─────────────────────────────────────────────────────────────
sudo npm install -g @anthropic-ai/claude-code
echo "Claude Code: $(claude --version 2>/dev/null || echo 'установлен')"

# ─────────────────────────────────────────────────────────────
echo_step "5. Настройка tmux"
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

# ─────────────────────────────────────────────────────────────
echo_step "6. Автозапуск Claude Code в tmux (сессия 'claude')"
# ─────────────────────────────────────────────────────────────
cat > "$USER_HOME/.claude-autostart.sh" << 'CLAUDE_EOF'
#!/bin/bash
# Запускает Claude Code в tmux-сессии если ещё не запущена
if ! tmux has-session -t claude 2>/dev/null; then
    tmux new-session -d -s claude -x 220 -y 50
    tmux send-keys -t claude "claude --dangerously-skip-permissions" Enter
fi
CLAUDE_EOF
chmod +x "$USER_HOME/.claude-autostart.sh"

# Desktop autostart entry (запускает при входе в GUI)
mkdir -p "$USER_HOME/.config/autostart"
cat > "$USER_HOME/.config/autostart/claude-tmux.desktop" << DESKTOP_EOF
[Desktop Entry]
Type=Application
Name=Claude Code (tmux)
Exec=xfce4-terminal --title="Claude Code" -e "bash -c '$USER_HOME/.claude-autostart.sh; tmux attach -t claude'"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
DESKTOP_EOF

# Также добавляем в .bashrc для запуска из терминала
if ! grep -q "claude-autostart" "$USER_HOME/.bashrc"; then
cat >> "$USER_HOME/.bashrc" << 'BASHRC_EOF'

# Автозапуск Claude Code в tmux
if [ -n "$DISPLAY" ] && [ -z "$TMUX" ] && [ "$TERM" != "linux" ]; then
    ~/.claude-autostart.sh
fi
BASHRC_EOF
fi

# ─────────────────────────────────────────────────────────────
echo_step "7. Тема Catppuccin Mocha GTK"
# ─────────────────────────────────────────────────────────────
mkdir -p "$USER_HOME/.themes"

# Скачиваем Catppuccin GTK тему
CATPPUCCIN_URL="https://github.com/catppuccin/gtk/releases/download/v1.0.3/Catppuccin-Mocha-Standard-Mauve-Dark.zip"
wget -q "$CATPPUCCIN_URL" -O /tmp/catppuccin-gtk.zip 2>/dev/null \
  && unzip -q /tmp/catppuccin-gtk.zip -d "$USER_HOME/.themes/" \
  && echo "Catppuccin тема скачана" \
  || echo "WARN: не удалось скачать тему (проверьте интернет), стиль будет применён позже"

# GTK3 settings
mkdir -p "$USER_HOME/.config/gtk-3.0"
cat > "$USER_HOME/.config/gtk-3.0/settings.ini" << 'GTK_EOF'
[Settings]
gtk-theme-name=Catppuccin-Mocha-Standard-Mauve-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-enable-event-sounds=0
gtk-enable-input-feedback-sounds=0
GTK_EOF

# GTK2 settings
cat > "$USER_HOME/.gtkrc-2.0" << 'GTK2_EOF'
gtk-theme-name="Catppuccin-Mocha-Standard-Mauve-Dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Noto Sans 10"
gtk-cursor-theme-name="Adwaita"
gtk-cursor-theme-size=24
GTK2_EOF

# xfconf (применяется после запуска XFCE)
mkdir -p "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
cat > "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" << 'XSET_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Catppuccin-Mocha-Standard-Mauve-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
  <property name="Xft" type="empty">
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
  </property>
</channel>
XSET_EOF

# ─────────────────────────────────────────────────────────────
echo_step "8. Настройка xfce4-terminal (Catppuccin цвета)"
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

# ─────────────────────────────────────────────────────────────
echo_step "9. Верхняя панель XFCE: время, громкость, дата (без года)"
# ─────────────────────────────────────────────────────────────
# Конфигурация панели через XML (применяется при первом запуске XFCE)
mkdir -p "$USER_HOME/.config/xfce4"
cat > "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" << 'PANEL_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="28"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="applicationsmenu"/>
    <property name="plugin-2" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
    </property>
    <property name="plugin-3" type="string" value="pulseaudio">
      <property name="show-notifications" type="bool" value="false"/>
    </property>
    <property name="plugin-4" type="string" value="clock">
      <property name="digital-format" type="string" value="%H:%M"/>
    </property>
    <property name="plugin-5" type="string" value="clock">
      <property name="digital-format" type="string" value="%d %B"/>
    </property>
  </property>
</channel>
PANEL_EOF

# ─────────────────────────────────────────────────────────────
echo_step "10. Горячие клавиши тайлинга окон (аналог Rectangle)"
# ─────────────────────────────────────────────────────────────
mkdir -p "$USER_HOME/.local/bin"

# Универсальный скрипт тайлинга
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
    W=$((WIDTH + 50)); H=$((HEIGHT + 30))
    move $X $Y $W $H ;;
  shrink)
    unmax
    GEOM=$(xdotool getwindowgeometry --shell "$WIN_ID")
    eval "$GEOM"
    W=$((WIDTH - 50)); H=$((HEIGHT - 30))
    move $X $Y $W $H ;;
esac
TILE_EOF
chmod +x "$USER_HOME/.local/bin/tile.sh"

# Добавляем ~/.local/bin в PATH
grep -q '.local/bin' "$USER_HOME/.bashrc" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.bashrc"

# Горячие клавиши через xfconf
# (аналог Rectangle: Super = ⌘, Alt = ⌥, Ctrl = ^)
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

# Смена языка: Super+Space
xfconf-query -c xfce4-keyboard-shortcuts \
  -p "/commands/custom/<Super>space" \
  -t string -s "xfce4-keyboard-settings" --create 2>/dev/null || true

# ─────────────────────────────────────────────────────────────
echo_step "11. Включение LightDM"
# ─────────────────────────────────────────────────────────────
sudo systemctl enable lightdm 2>/dev/null || true

# ─────────────────────────────────────────────────────────────
echo_step "12. XFCE Desktop / Wallpaper настройка"
# ─────────────────────────────────────────────────────────────
mkdir -p "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
cat > "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" << 'DESK_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorVirtual-1" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="rgba1" type="array">
            <value type="double" value="0.117647"/>
            <value type="double" value="0.117647"/>
            <value type="double" value="0.180392"/>
            <value type="double" value="1.000000"/>
          </property>
          <property name="image-style" type="int" value="0"/>
        </property>
      </property>
    </property>
  </property>
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="0"/>
  </property>
</channel>
DESK_EOF

# ─────────────────────────────────────────────────────────────
echo ""
echo -e "\033[1;32m╔══════════════════════════════════════════════════════════╗"
echo    "║           УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!                   ║"
echo    "╠══════════════════════════════════════════════════════════╣"
echo    "║  ✓ XFCE4 + Openbox + LightDM                            ║"
echo    "║  ✓ Node.js LTS + Claude Code                            ║"
echo    "║  ✓ Claude Code автозапуск → tmux сессия 'claude'        ║"
echo    "║    режим: --dangerously-skip-permissions                 ║"
echo    "║  ✓ tmux конфиг (Catppuccin #A88CCA)                     ║"
echo    "║  ✓ Catppuccin Mocha тема GTK + Papirus иконки           ║"
echo    "║  ✓ Верхняя панель: время (ЧЧ:ММ), громкость, дата       ║"
echo    "║  ✓ Горячие клавиши тайлинга (аналог Rectangle)          ║"
echo    "║  ✓ xfce4-terminal Catppuccin цвета                      ║"
echo    "╠══════════════════════════════════════════════════════════╣"
echo    "║  ДАЛЕЕ:                                                  ║"
echo    "║   sudo reboot                                            ║"
echo    "║   → войдите в XFCE сессию через LightDM                 ║"
echo    "║   → Claude Code запустится автоматически                ║"
echo    "║   → или: tmux attach -t claude                          ║"
echo    "╠══════════════════════════════════════════════════════════╣"
echo    "║  ГОРЯЧИЕ КЛАВИШИ ТАЙЛИНГА:                              ║"
echo    "║   Super+← / →     : левая / правая половина             ║"
echo    "║   Super+↑ / ↓     : верхняя / нижняя половина          ║"
echo    "║   Alt+Super+← / → : верхний угол лево / право           ║"
echo    "║   Ctrl+Alt+← / →  : нижний угол лево / право            ║"
echo    "║   Ctrl+Super+F    : максимизировать                      ║"
echo    "║   Ctrl+Super+C    : по центру                            ║"
echo    "║   Super+Space     : смена языка                          ║"
echo -e "╚══════════════════════════════════════════════════════════╝\033[0m"
