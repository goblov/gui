#!/bin/bash

set -e

# ─── Цвета ───────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${CYAN}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }

DIR="$HOME/.filetree"

# ─── 1. Node.js ──────────────────────────────────────────────────────
log "Проверка Node.js..."
if ! command -v node &>/dev/null; then
  warn "Node.js не найден. Устанавливаю..."
  sudo apt-get update -qq
  sudo apt-get install -y nodejs npm || fail "Не удалось установить Node.js"
fi

NODE_VER=$(node --version | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VER" -lt 18 ]; then
  warn "Node.js версия слишком старая ($NODE_VER). Нужна 18+. Устанавливаю через nvm..."
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  source "$NVM_DIR/nvm.sh"
  nvm install 20
  nvm use 20
fi
ok "Node.js $(node --version)"

# ─── 2. Создание проекта ─────────────────────────────────────────────
log "Создание проекта в $DIR..."
mkdir -p "$DIR/src" "$DIR/public"

# package.json
cat > "$DIR/package.json" << 'EOF'
{
  "name": "filetree",
  "version": "1.0.0",
  "description": "Custom file manager",
  "main": "main.js",
  "scripts": {
    "start": "electron .",
    "dev": "concurrently \"vite\" \"wait-on http://localhost:5173 && electron .\"",
    "build": "vite build && electron-builder"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.0.0",
    "electron": "^28.0.0",
    "vite": "^5.0.0"
  }
}
EOF

# vite.config.js
cat > "$DIR/vite.config.js" << 'EOF'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
export default defineConfig({
  plugins: [react()],
  base: "./",
  build: { outDir: "dist" },
});
EOF

# index.html
cat > "$DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="ru">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>FileTree</title>
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body { overflow: hidden; background: #1e1e2e; }
      ::-webkit-scrollbar { width: 4px; }
      ::-webkit-scrollbar-track { background: transparent; }
      ::-webkit-scrollbar-thumb { background: #ffffff20; border-radius: 2px; }
    </style>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

# main.js
cat > "$DIR/main.js" << 'EOF'
const { app, BrowserWindow, ipcMain, shell } = require("electron");
const path = require("path");
const fs = require("fs");
const os = require("os");

const isDev = process.env.NODE_ENV === "development";

function createWindow() {
  const win = new BrowserWindow({
    width: 380,
    height: 700,
    minWidth: 280,
    minHeight: 400,
    frame: false,
    backgroundColor: "#1e1e2e",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  if (isDev) {
    win.loadURL("http://localhost:5173");
  } else {
    win.loadFile(path.join(__dirname, "dist", "index.html"));
  }
}

ipcMain.handle("fs:readdir", (_, dirPath) => {
  try {
    const entries = fs.readdirSync(dirPath, { withFileTypes: true });
    return entries.map((e) => ({
      name: e.name,
      type: e.isDirectory() ? "folder" : "file",
      path: path.join(dirPath, e.name),
    }));
  } catch { return []; }
});

ipcMain.handle("fs:homedir", () => os.homedir());
ipcMain.handle("fs:open", (_, filePath) => shell.openPath(filePath));

ipcMain.on("win:minimize", (e) => BrowserWindow.fromWebContents(e.sender)?.minimize());
ipcMain.on("win:maximize", (e) => {
  const win = BrowserWindow.fromWebContents(e.sender);
  if (win?.isMaximized()) win.unmaximize(); else win?.maximize();
});
ipcMain.on("win:close", (e) => BrowserWindow.fromWebContents(e.sender)?.close());

app.whenReady().then(createWindow);
app.on("window-all-closed", () => app.quit());
EOF

# preload.js
cat > "$DIR/preload.js" << 'EOF'
const { contextBridge, ipcRenderer } = require("electron");
contextBridge.exposeInMainWorld("electronAPI", {
  readdir:  (path) => ipcRenderer.invoke("fs:readdir", path),
  homedir:  ()     => ipcRenderer.invoke("fs:homedir"),
  openFile: (path) => ipcRenderer.invoke("fs:open", path),
  minimize: ()     => ipcRenderer.send("win:minimize"),
  maximize: ()     => ipcRenderer.send("win:maximize"),
  close:    ()     => ipcRenderer.send("win:close"),
});
EOF

# src/main.jsx
cat > "$DIR/src/main.jsx" << 'EOF'
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App.jsx";
ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode><App /></React.StrictMode>
);
EOF

# src/App.jsx
cat > "$DIR/src/App.jsx" << 'APPEOF'
import { useState, useEffect, useCallback } from "react";

const DEFAULT_COLOR = "#b39ddb";
const api = window.electronAPI;

function FolderIcon({ color, open }) {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" style={{ flexShrink: 0 }}>
      <path
        d="M2 6C2 4.9 2.9 4 4 4H9.17C9.7 4 10.21 4.21 10.59 4.59L12 6H20C21.1 6 22 6.9 22 8V18C22 19.1 21.1 20 20 20H4C2.9 20 2 19.1 2 18V6Z"
        fill={open ? color + "33" : color + "22"}
        stroke={color} strokeWidth="1.5" strokeLinejoin="round"
      />
      {open && <path d="M2 10H22" stroke={color} strokeWidth="1.2" strokeOpacity="0.5" />}
    </svg>
  );
}

function FileIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" style={{ flexShrink: 0 }}>
      <path d="M13 2H6C4.9 2 4 2.9 4 4V20C4 21.1 4.9 22 6 22H18C19.1 22 20 21.1 20 20V9L13 2Z"
        fill="#ffffff0d" stroke="#666" strokeWidth="1.5" strokeLinejoin="round" />
      <path d="M13 2V9H20" stroke="#666" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function ChevronIcon({ open }) {
  return (
    <svg width="9" height="9" viewBox="0 0 10 10" fill="none"
      style={{ flexShrink: 0, transition: "transform 0.15s", transform: open ? "rotate(90deg)" : "rotate(0deg)" }}>
      <path d="M3 2L7 5L3 8" stroke="#666" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function TreeNode({ node, depth, color, onNavigate }) {
  const [open, setOpen] = useState(false);
  const [children, setChildren] = useState(null);
  const isFolder = node.type === "folder";

  const handleClick = useCallback(async () => {
    if (!isFolder) { api?.openFile(node.path); return; }
    if (!open && children === null) {
      const items = await api?.readdir(node.path) ?? [];
      const sorted = [...items].sort((a, b) => {
        if (a.type === b.type) return a.name.localeCompare(b.name);
        return a.type === "folder" ? -1 : 1;
      });
      setChildren(sorted);
    }
    setOpen((o) => !o);
  }, [isFolder, open, children, node.path]);

  return (
    <div>
      <div
        style={{
          display: "flex", alignItems: "center", gap: "5px",
          padding: `3px 8px 3px ${8 + depth * 14}px`,
          cursor: "pointer", borderRadius: "4px",
          userSelect: "none", fontSize: "12.5px", color: "#ccc",
          transition: "background 0.1s", WebkitAppRegion: "no-drag",
        }}
        onClick={handleClick}
        onDoubleClick={() => isFolder && onNavigate?.(node.path)}
        onMouseEnter={(e) => (e.currentTarget.style.background = "#ffffff0d")}
        onMouseLeave={(e) => (e.currentTarget.style.background = "transparent")}
      >
        {isFolder ? (<><ChevronIcon open={open} /><FolderIcon color={color} open={open} /></>) : (<><span style={{ width: 9 }} /><FileIcon /></>)}
        <span style={{ marginLeft: 2, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{node.name}</span>
      </div>
      {isFolder && open && children?.map((child, i) => (
        <TreeNode key={i} node={child} depth={depth + 1} color={color} onNavigate={onNavigate} />
      ))}
    </div>
  );
}

function TBtn({ title, onClick, children }) {
  return (
    <button title={title} onClick={onClick}
      style={{ background: "transparent", border: "none", cursor: "pointer", padding: "4px", display: "flex", alignItems: "center", color: "#666", borderRadius: "3px", transition: "color 0.1s", WebkitAppRegion: "no-drag" }}
      onMouseEnter={(e) => (e.currentTarget.style.color = "#bbb")}
      onMouseLeave={(e) => (e.currentTarget.style.color = "#666")}
    >{children}</button>
  );
}

export default function App() {
  const [color, setColor] = useState(DEFAULT_COLOR);
  const [currentPath, setCurrentPath] = useState("~");
  const [tree, setTree] = useState([]);
  const [search, setSearch] = useState("");
  const [showSearch, setShowSearch] = useState(false);

  const loadDir = useCallback(async (dirPath) => {
    const items = await api?.readdir(dirPath) ?? [];
    const sorted = [...items].sort((a, b) => {
      if (a.type === b.type) return a.name.localeCompare(b.name);
      return a.type === "folder" ? -1 : 1;
    });
    setTree(sorted);
    setCurrentPath(dirPath);
  }, []);

  useEffect(() => {
    (async () => { const home = await api?.homedir() ?? "/home"; loadDir(home); })();
  }, []);

  const goUp = () => {
    const parent = currentPath.split("/").slice(0, -1).join("/") || "/";
    loadDir(parent);
  };

  const filtered = search ? tree.filter((n) => n.name.toLowerCase().includes(search.toLowerCase())) : tree;
  const displayPath = currentPath.replace(/^\/home\/[^/]+/, "~");

  return (
    <div style={{ background: "#1e1e2e", height: "100vh", fontFamily: "'JetBrains Mono', 'Fira Mono', monospace", display: "flex", flexDirection: "column", overflow: "hidden" }}>
      <div style={{ background: "#13131f", borderBottom: "1px solid #ffffff0f", padding: "8px 10px", display: "flex", alignItems: "center", justifyContent: "space-between", WebkitAppRegion: "drag", flexShrink: 0 }}>
        <div style={{ display: "flex", alignItems: "center", gap: "2px" }}>
          <TBtn title="Вверх" onClick={goUp}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><polyline points="18 15 12 9 6 15" /></svg>
          </TBtn>
          <TBtn title="Обновить" onClick={() => loadDir(currentPath)}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><polyline points="23 4 23 10 17 10" /><polyline points="1 20 1 14 7 14" /><path d="M3.51 9a9 9 0 0114.36-3.36L23 10M1 14l5.13 4.36A9 9 0 0020.49 15" /></svg>
          </TBtn>
          <TBtn title="Поиск" onClick={() => setShowSearch((s) => !s)}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="7" /><line x1="21" y1="21" x2="16.65" y2="16.65" /></svg>
          </TBtn>
        </div>
        <span style={{ color: "#555", fontSize: "11px", letterSpacing: "0.04em", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", maxWidth: "140px" }}>{displayPath}</span>
        <div style={{ display: "flex", alignItems: "center", gap: "4px" }}>
          <input type="color" value={color} onChange={(e) => setColor(e.target.value)} title="Цвет папок"
            style={{ width: "14px", height: "14px", borderRadius: "50%", border: "none", cursor: "pointer", background: "transparent", padding: 0, WebkitAppRegion: "no-drag" }} />
          <div style={{ width: "1px", height: "12px", background: "#ffffff10", margin: "0 3px" }} />
          <TBtn title="Свернуть" onClick={() => api?.minimize()}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><line x1="5" y1="12" x2="19" y2="12" /></svg>
          </TBtn>
          <TBtn title="Развернуть" onClick={() => api?.maximize()}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="4" y="4" width="16" height="16" rx="1" /></svg>
          </TBtn>
          <TBtn title="Закрыть" onClick={() => api?.close()}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>
          </TBtn>
        </div>
      </div>

      {showSearch && (
        <div style={{ background: "#13131f", borderBottom: "1px solid #ffffff0f", padding: "5px 10px" }}>
          <input autoFocus value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Поиск..."
            style={{ width: "100%", background: "#ffffff08", border: "1px solid #ffffff12", borderRadius: "4px", color: "#ccc", fontSize: "12px", padding: "4px 8px", outline: "none", fontFamily: "inherit" }} />
        </div>
      )}

      <div style={{ overflowY: "auto", flex: 1, padding: "4px 0" }}>
        {filtered.length === 0 && (
          <div style={{ color: "#444", fontSize: "12px", padding: "16px", textAlign: "center" }}>
            {search ? "Ничего не найдено" : "Папка пуста"}
          </div>
        )}
        {filtered.map((node, i) => (
          <TreeNode key={i} node={node} depth={0} color={color} onNavigate={loadDir} />
        ))}
      </div>
    </div>
  );
}
APPEOF

ok "Файлы проекта созданы"

# ─── 3. npm install (с зеркалом и таймаутом) ─────────────────────────
log "Установка зависимостей..."
cd "$DIR"

# Зеркало для Electron (решает проблему обрыва загрузки бинарника)
export ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/"
export npm_config_fetch_timeout=300000
export npm_config_fetch_retries=5

npm install 2>&1 | tail -5 || fail "npm install завершился с ошибкой"
ok "Зависимости установлены"

ELECTRON_BIN="$DIR/node_modules/.bin/electron"

# ─── 4. Сборка React → dist ──────────────────────────────────────────
log "Сборка интерфейса..."
npx vite build --logLevel warn || fail "Сборка vite завершилась с ошибкой"
ok "Интерфейс собран"

# ─── 5. Запуск ───────────────────────────────────────────────────────
log "Запуск FileTree..."
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  FileTree запущен!${NC}"
echo -e "${CYAN}  Ctrl+C — закрыть из терминала${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

"$ELECTRON_BIN" .
