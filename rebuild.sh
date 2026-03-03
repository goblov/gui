#!/bin/bash
# Пересборка filetree после обновления App.jsx
DIR="$HOME/.filetree"
VITE="$DIR/node_modules/.bin/vite"
[ -f "$VITE" ] || { echo "ОШИБКА: vite не найден в $DIR"; exit 1; }
rm -rf "$DIR/dist"
cd "$DIR"
"$VITE" build --logLevel warn && echo "✓ Собрано успешно" || echo "✗ Ошибка сборки"
echo ""
echo "Перезапусти filetree: filetree"
