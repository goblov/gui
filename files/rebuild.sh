#!/bin/bash
# FileTree quick update: copy new files + rebuild + launch
# Положи App.jsx, main.js, preload.js рядом с этим скриптом и запусти
GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${CYAN}> $1${NC}"; }
ok()   { echo -e "${GREEN}OK: $1${NC}"; }
fail() { echo -e "${RED}FAIL: $1${NC}"; exit 1; }

DIR="$HOME/.filetree"
VITE_BIN="$DIR/node_modules/.bin/vite"
ELECTRON_BIN="$DIR/node_modules/.bin/electron"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -d "$DIR" ]          || fail "Not installed. Run filemanager.sh first."
[ -f "$VITE_BIN" ]     || fail "Vite not found. Run filemanager.sh first."
[ -f "$ELECTRON_BIN" ] || fail "Electron not found. Run filemanager.sh first."

log "Copying updated files..."
[ -f "$HERE/App.jsx" ]    && { cp "$HERE/App.jsx"    "$DIR/src/App.jsx";   ok "App.jsx";    } || fail "App.jsx not found next to this script"
[ -f "$HERE/main.js" ]    && { cp "$HERE/main.js"    "$DIR/main.js";       ok "main.js";    }
[ -f "$HERE/preload.js" ] && { cp "$HERE/preload.js"  "$DIR/preload.js";   ok "preload.js"; }

log "Building..."
rm -rf "$DIR/dist"
cd "$DIR"
"$VITE_BIN" build --logLevel warn || fail "Build failed"
ok "Build complete"

echo ""
echo "=============================="
echo "  FileTree updated!"
echo "  Ctrl+C to stop."
echo "=============================="
echo ""
export DISPLAY="${DISPLAY:-:0}"
exec "$ELECTRON_BIN" . --no-sandbox
