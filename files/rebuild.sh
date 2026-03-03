#!/bin/bash
GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${CYAN}> $1${NC}"; }
ok()   { echo -e "${GREEN}OK: $1${NC}"; }
fail() { echo -e "${RED}FAIL: $1${NC}"; exit 1; }

DIR="$HOME/.filetree"
VITE="$DIR/node_modules/.bin/vite"
ELECTRON="$DIR/node_modules/.bin/electron"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -d "$DIR" ]    || fail "Not installed. Run filemanager.sh first."
[ -f "$VITE" ]   || fail "Run filemanager.sh first."
[ -f "$ELECTRON" ] || fail "Run filemanager.sh first."

log "Copying files..."
[ -f "$HERE/App.jsx" ]    && cp "$HERE/App.jsx"    "$DIR/src/App.jsx"   && ok "App.jsx"
[ -f "$HERE/main.js" ]    && cp "$HERE/main.js"    "$DIR/main.js"       && ok "main.js"
[ -f "$HERE/preload.js" ] && cp "$HERE/preload.js" "$DIR/preload.js"    && ok "preload.js"

log "Building..."
rm -rf "$DIR/dist"
cd "$DIR"
"$VITE" build --logLevel warn || fail "Build failed"
ok "Done"

echo ""
echo "=============================="
echo "  Running FileTree..."
echo "  Ctrl+C to stop."
echo "=============================="
export DISPLAY="${DISPLAY:-:0}"
exec "$ELECTRON" . --no-sandbox
