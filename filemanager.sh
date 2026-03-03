#!/bin/bash
set -eo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }

DIR="$HOME/.filetree"
ELECTRON_BIN="$DIR/node_modules/.bin/electron"
VITE_BIN="$DIR/node_modules/.bin/vite"

log "Проверка Node.js..."
if ! command -v node &>/dev/null; then
  sudo apt-get update -qq && sudo apt-get install -y nodejs npm || fail "Не удалось установить Node.js"
fi
ok "Node.js $(node --version)"

if [ ! -f "$DIR/package.json" ]; then
  log "Создание проекта..."
  mkdir -p "$DIR/src"

  cat > "$DIR/package.json" << 'EOF'
{"name":"filetree","version":"1.0.0","main":"main.js","dependencies":{"react":"^18.2.0","react-dom":"^18.2.0"},"devDependencies":{"@vitejs/plugin-react":"^4.0.0","vite":"^5.0.0"}}
EOF

  cat > "$DIR/vite.config.js" << 'EOF'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
export default defineConfig({ plugins: [react()], base: "./" });
EOF

  cat > "$DIR/index.html" << 'EOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"/><style>*{margin:0;padding:0;box-sizing:border-box}body{overflow:hidden;background:#1e1e2e}::-webkit-scrollbar{width:4px}::-webkit-scrollbar-thumb{background:#ffffff20;border-radius:2px}</style></head><body><div id="root"></div><script type="module" src="/src/main.jsx"></script></body></html>
EOF

  cat > "$DIR/main.js" << 'EOF'
const{app,BrowserWindow,ipcMain,shell}=require("electron"),path=require("path"),fs=require("fs"),os=require("os");
function createWindow(){const w=new BrowserWindow({width:380,height:700,minWidth:280,minHeight:400,frame:false,backgroundColor:"#1e1e2e",webPreferences:{preload:path.join(__dirname,"preload.js"),contextIsolation:true,nodeIntegration:false}});w.loadFile(path.join(__dirname,"dist","index.html"));}
ipcMain.handle("fs:readdir",(_,p)=>{try{return fs.readdirSync(p,{withFileTypes:true}).map(e=>({name:e.name,type:e.isDirectory()?"folder":"file",path:path.join(p,e.name)}))}catch{return[]}});
ipcMain.handle("fs:homedir",()=>os.homedir());
ipcMain.handle("fs:open",(_,p)=>shell.openPath(p));
ipcMain.on("win:minimize",e=>BrowserWindow.fromWebContents(e.sender)?.minimize());
ipcMain.on("win:maximize",e=>{const w=BrowserWindow.fromWebContents(e.sender);w?.isMaximized()?w.unmaximize():w?.maximize()});
ipcMain.on("win:close",e=>BrowserWindow.fromWebContents(e.sender)?.close());
app.whenReady().then(createWindow);
app.on("window-all-closed",()=>app.quit());
EOF

  cat > "$DIR/preload.js" << 'EOF'
const{contextBridge,ipcRenderer}=require("electron");
contextBridge.exposeInMainWorld("electronAPI",{readdir:p=>ipcRenderer.invoke("fs:readdir",p),homedir:()=>ipcRenderer.invoke("fs:homedir"),openFile:p=>ipcRenderer.invoke("fs:open",p),minimize:()=>ipcRenderer.send("win:minimize"),maximize:()=>ipcRenderer.send("win:maximize"),close:()=>ipcRenderer.send("win:close")});
EOF

  cat > "$DIR/src/main.jsx" << 'EOF'
import React from "react";import ReactDOM from "react-dom/client";import App from "./App.jsx";
ReactDOM.createRoot(document.getElementById("root")).render(<React.StrictMode><App/></React.StrictMode>);
EOF

  ok "Файлы проекта созданы"
else
  ok "Проект существует — пропускаю"
fi

# App.jsx через python чтобы избежать проблем с кавычками в heredoc
python3 - << 'PYEOF'
import os
src = os.path.expanduser("~/.filetree/src")
os.makedirs(src, exist_ok=True)
app_path = os.path.join(src, "App.jsx")
if os.path.exists(app_path):
    print("App.jsx exists — skip")
else:
    code = open("/dev/stdin").read() if False else None
    # write inline
    with open(app_path, "w") as f:
        f.write("""import { useState, useEffect, useCallback } from "react";
const DEFAULT_COLOR = "#b39ddb";
const api = window.electronAPI;
function FolderIcon({ color, open }) {
  return (<svg width="16" height="16" viewBox="0 0 24 24" fill="none" style={{ flexShrink: 0 }}>
    <path d="M2 6C2 4.9 2.9 4 4 4H9.17C9.7 4 10.21 4.21 10.59 4.59L12 6H20C21.1 6 22 6.9 22 8V18C22 19.1 21.1 20 20 20H4C2.9 20 2 19.1 2 18V6Z"
      fill={open ? color+"33" : color+"22"} stroke={color} strokeWidth="1.5" strokeLinejoin="round"/>
    {open && <path d="M2 10H22" stroke={color} strokeWidth="1.2" strokeOpacity="0.5"/>}
  </svg>);
}
function FileIcon() {
  return (<svg width="14" height="14" viewBox="0 0 24 24" fill="none" style={{ flexShrink: 0 }}>
    <path d="M13 2H6C4.9 2 4 2.9 4 4V20C4 21.1 4.9 22 6 22H18C19.1 22 20 21.1 20 20V9L13 2Z" fill="#ffffff0d" stroke="#666" strokeWidth="1.5" strokeLinejoin="round"/>
    <path d="M13 2V9H20" stroke="#666" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>);
}
function ChevronIcon({ open }) {
  return (<svg width="9" height="9" viewBox="0 0 10 10" fill="none"
    style={{ flexShrink:0, transition:"transform 0.15s", transform: open?"rotate(90deg)":"rotate(0deg)" }}>
    <path d="M3 2L7 5L3 8" stroke="#666" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>);
}
function TreeNode({ node, depth, color, onNavigate }) {
  const [open, setOpen] = useState(false);
  const [children, setChildren] = useState(null);
  const isFolder = node.type === "folder";
  const handleClick = useCallback(async () => {
    if (!isFolder) { api?.openFile(node.path); return; }
    if (!open && children === null) {
      const items = await api?.readdir(node.path) ?? [];
      setChildren([...items].sort((a,b) => a.type===b.type ? a.name.localeCompare(b.name) : a.type==="folder"?-1:1));
    }
    setOpen(o => !o);
  }, [isFolder, open, children, node.path]);
  return (<div>
    <div style={{ display:"flex", alignItems:"center", gap:"5px", padding:`3px 8px 3px ${8+depth*14}px`,
        cursor:"pointer", borderRadius:"4px", userSelect:"none", fontSize:"12.5px", color:"#ccc",
        transition:"background 0.1s", WebkitAppRegion:"no-drag" }}
      onClick={handleClick}
      onDoubleClick={() => isFolder && onNavigate?.(node.path)}
      onMouseEnter={e => e.currentTarget.style.background="#ffffff0d"}
      onMouseLeave={e => e.currentTarget.style.background="transparent"}>
      {isFolder ? (<><ChevronIcon open={open}/><FolderIcon color={color} open={open}/></>)
                : (<><span style={{width:9}}/><FileIcon/></>)}
      <span style={{marginLeft:2, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap"}}>{node.name}</span>
    </div>
    {isFolder && open && children?.map((child,i) => (
      <TreeNode key={i} node={child} depth={depth+1} color={color} onNavigate={onNavigate}/>
    ))}
  </div>);
}
function TBtn({ title, onClick, children }) {
  return (<button title={title} onClick={onClick}
    style={{ background:"transparent", border:"none", cursor:"pointer", padding:"4px", display:"flex",
      alignItems:"center", color:"#666", borderRadius:"3px", transition:"color 0.1s", WebkitAppRegion:"no-drag" }}
    onMouseEnter={e => e.currentTarget.style.color="#bbb"}
    onMouseLeave={e => e.currentTarget.style.color="#666"}>{children}</button>);
}
export default function App() {
  const [color, setColor] = useState(DEFAULT_COLOR);
  const [currentPath, setCurrentPath] = useState("~");
  const [tree, setTree] = useState([]);
  const [search, setSearch] = useState("");
  const [showSearch, setShowSearch] = useState(false);
  const loadDir = useCallback(async (dirPath) => {
    const items = await api?.readdir(dirPath) ?? [];
    setTree([...items].sort((a,b) => a.type===b.type ? a.name.localeCompare(b.name) : a.type==="folder"?-1:1));
    setCurrentPath(dirPath);
  }, []);
  useEffect(() => { (async () => { const home = await api?.homedir() ?? "/home"; loadDir(home); })(); }, []);
  const goUp = () => loadDir(currentPath.split("/").slice(0,-1).join("/")||"/");
  const filtered = search ? tree.filter(n => n.name.toLowerCase().includes(search.toLowerCase())) : tree;
  const displayPath = currentPath.replace(/^\\/home\\/[^/]+/, "~");
  return (
    <div style={{ background:"#1e1e2e", height:"100vh", fontFamily:"'JetBrains Mono','Fira Mono',monospace", display:"flex", flexDirection:"column", overflow:"hidden" }}>
      <div style={{ background:"#13131f", borderBottom:"1px solid #ffffff0f", padding:"8px 10px", display:"flex", alignItems:"center", justifyContent:"space-between", WebkitAppRegion:"drag", flexShrink:0 }}>
        <div style={{ display:"flex", alignItems:"center", gap:"2px" }}>
          <TBtn title="Вверх" onClick={goUp}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><polyline points="18 15 12 9 6 15"/></svg></TBtn>
          <TBtn title="Обновить" onClick={() => loadDir(currentPath)}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0114.36-3.36L23 10M1 14l5.13 4.36A9 9 0 0020.49 15"/></svg></TBtn>
          <TBtn title="Поиск" onClick={() => setShowSearch(s => !s)}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg></TBtn>
        </div>
        <span style={{ color:"#555", fontSize:"11px", overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap", maxWidth:"140px" }}>{displayPath}</span>
        <div style={{ display:"flex", alignItems:"center", gap:"4px" }}>
          <input type="color" value={color} onChange={e => setColor(e.target.value)} title="Цвет папок" style={{ width:"14px", height:"14px", borderRadius:"50%", border:"none", cursor:"pointer", padding:0, WebkitAppRegion:"no-drag" }}/>
          <div style={{ width:"1px", height:"12px", background:"#ffffff10", margin:"0 3px" }}/>
          <TBtn title="Свернуть" onClick={() => api?.minimize()}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><line x1="5" y1="12" x2="19" y2="12"/></svg></TBtn>
          <TBtn title="Развернуть" onClick={() => api?.maximize()}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="4" y="4" width="16" height="16" rx="1"/></svg></TBtn>
          <TBtn title="Закрыть" onClick={() => api?.close()}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></TBtn>
        </div>
      </div>
      {showSearch && (<div style={{ background:"#13131f", borderBottom:"1px solid #ffffff0f", padding:"5px 10px" }}>
        <input autoFocus value={search} onChange={e => setSearch(e.target.value)} placeholder="Поиск..."
          style={{ width:"100%", background:"#ffffff08", border:"1px solid #ffffff12", borderRadius:"4px", color:"#ccc", fontSize:"12px", padding:"4px 8px", outline:"none", fontFamily:"inherit" }}/>
      </div>)}
      <div style={{ overflowY:"auto", flex:1, padding:"4px 0" }}>
        {filtered.length === 0 && <div style={{ color:"#444", fontSize:"12px", padding:"16px", textAlign:"center" }}>{search ? "Ничего не найдено" : "Папка пуста"}</div>}
        {filtered.map((node,i) => (<TreeNode key={i} node={node} depth={0} color={color} onNavigate={loadDir}/>))}
      </div>
    </div>
  );
}
""")
    print("App.jsx written")
PYEOF

# ─── 3. React + Vite (без electron — быстро) ─────────────────────────
if [ ! -f "$VITE_BIN" ]; then
  log "Установка React + Vite..."
  cd "$DIR"
  npm config set registry https://registry.npmmirror.com
  npm install || fail "npm install завершился с ошибкой"
  ok "React + Vite установлены"
else
  ok "React + Vite — пропускаю"
fi

# ─── 4. Electron отдельно с зеркалом ─────────────────────────────────
if [ ! -f "$ELECTRON_BIN" ]; then
  log "Установка Electron (может занять несколько минут)..."
  cd "$DIR"
  export ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/"
  npm install electron@28 --save-dev || fail "Не удалось установить Electron"
  ok "Electron установлен"
else
  ok "Electron — пропускаю"
fi

# ─── 5. Сборка ───────────────────────────────────────────────────────
if [ ! -d "$DIR/dist" ]; then
  log "Сборка интерфейса..."
  cd "$DIR"
  "$VITE_BIN" build --logLevel warn || fail "Сборка завершилась с ошибкой"
  ok "Интерфейс собран"
else
  ok "Интерфейс собран — пропускаю"
fi

# ─── 7. Регистрация как файловый менеджер ────────────────────────────
DESKTOP_FILE="$HOME/.local/share/applications/filetree.desktop"
mkdir -p "$HOME/.local/share/applications"
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=FileTree
Comment=Custom file manager
Exec=$ELECTRON_BIN $DIR --no-sandbox %U
Icon=system-file-manager
Terminal=false
Type=Application
Categories=System;FileManager;
MimeType=inode/directory;
StartupNotify=true
EOF

# Назначаем дефолтным для папок
xdg-mime default filetree.desktop inode/directory
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
ok "Зарегистрирован как файловый менеджер по умолчанию"

# ─── 8. Запуск ───────────────────────────────────────────────────────
log "Запуск FileTree..."
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  FileTree запущен!${NC}"
echo -e "${CYAN}  Ctrl+C — закрыть из терминала${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
export DISPLAY="${DISPLAY:-:0}"
cd "$DIR"
"$ELECTRON_BIN" . --no-sandbox
