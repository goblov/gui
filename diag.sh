#!/bin/bash
# Диагностика - запусти и скинь вывод

echo "=== ПАНЕЛИ ==="
xfconf-query -c xfce4-panel -p /panels 2>&1

echo ""
echo "=== ВСЕ ПЛАГИНЫ ПАНЕЛЕЙ ==="
xfconf-query -c xfce4-panel -l 2>&1 | grep "^/panels" | head -30

echo ""
echo "=== ТЕКУЩАЯ GTK ТЕМА ==="
xfconf-query -c xsettings -p /Net/ThemeName 2>&1

echo ""
echo "=== ТЕМЫ В ~/.themes ==="
ls -la "$HOME/.themes/" 2>&1

echo ""
echo "=== ТЕМЫ В /usr/share/themes ==="
ls /usr/share/themes/ 2>&1

echo ""
echo "=== МОНИТОР ==="
xrandr --query 2>&1 | grep " connected"

echo ""
echo "=== DBUS ==="
echo "DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS"

echo ""
echo "=== XFCE ПРОЦЕССЫ ==="
ps aux | grep -E "xfce|xfwm|xfdesktop|xfce4-panel" | grep -v grep

echo ""
echo "=== CONFIG ПАПКИ ==="
ls "$HOME/.config/xfce4/" 2>&1
