#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}> $1${NC}"; }
ok()   { echo -e "${GREEN}OK: $1${NC}"; }
fail() { echo -e "${RED}FAIL: $1${NC}"; exit 1; }

DIR="$HOME/.filetree"
ELECTRON_BIN="$DIR/node_modules/.bin/electron"
VITE_BIN="$DIR/node_modules/.bin/vite"
WRAPPER="$HOME/.local/bin/filetree"
THUNAR_WRAPPER="$HOME/.local/bin/thunar"

# Node.js
log "Checking Node.js..."
if ! command -v node &>/dev/null; then
  log "Node.js not found, installing..."
  if command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y nodejs npm || fail "Cannot install Node.js"
  elif [ "$(id -u)" = "0" ]; then
    apt-get update -qq && apt-get install -y nodejs npm || fail "Cannot install Node.js"
  else
    fail "Node.js not found. Run: sudo apt-get install nodejs npm"
  fi
fi
ok "Node.js $(node --version)"

# Remove Thunar
log "Removing Thunar..."
if command -v thunar &>/dev/null || dpkg -l thunar &>/dev/null 2>&1; then
  if command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
    sudo apt-get remove -y thunar thunar-archive-plugin thunar-media-tags-plugin thunar-volman 2>/dev/null || true
  elif [ "$(id -u)" = "0" ]; then
    apt-get remove -y thunar thunar-archive-plugin thunar-media-tags-plugin thunar-volman 2>/dev/null || true
  else
    ok "Thunar found but cannot remove without sudo (skipping)"
  fi
  ok "Thunar removed"
else
  ok "Thunar not installed -- skip"
fi

mkdir -p "$DIR/src"

[ -f "$DIR/package.json" ] || echo '{"name":"filetree","version":"1.0.0","main":"main.js","dependencies":{"react":"^18.2.0","react-dom":"^18.2.0"},"devDependencies":{"@vitejs/plugin-react":"^4.0.0","vite":"^5.0.0"}}' > "$DIR/package.json"

cat > "$DIR/vite.config.js" << 'VEOF'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
export default defineConfig({ plugins: [react()], base: "./" });
VEOF

cat > "$DIR/index.html" << 'HEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"/><style>*{margin:0;padding:0;box-sizing:border-box}body{overflow:hidden;background:#1e1e2e}::-webkit-scrollbar{width:4px}::-webkit-scrollbar-thumb{background:#ffffff20;border-radius:2px}</style></head><body><div id="root"></div><script type="module" src="/src/main.jsx"></script></body></html>
HEOF

cat > "$DIR/main.js" << 'MEOF'
const{app,BrowserWindow,ipcMain,shell}=require("electron"),path=require("path"),fs=require("fs"),os=require("os");
function getStartPath(){
  const args=process.argv.slice(2).filter(a=>!a.startsWith("--"));
  if(args.length>0&&fs.existsSync(args[0]))return args[0];
  return os.homedir();
}
function createWindow(){
  const w=new BrowserWindow({width:380,height:700,minWidth:280,minHeight:400,frame:false,backgroundColor:"#1e1e2e",
    webPreferences:{preload:path.join(__dirname,"preload.js"),contextIsolation:true,nodeIntegration:false}});
  w.loadFile(path.join(__dirname,"dist","index.html"));
}
ipcMain.handle("fs:readdir",(_,p)=>{try{return fs.readdirSync(p,{withFileTypes:true}).map(e=>({name:e.name,type:e.isDirectory()?"folder":"file",path:path.join(p,e.name)}))}catch{return[]}});
ipcMain.handle("fs:homedir",()=>os.homedir());
ipcMain.handle("fs:startpath",()=>getStartPath());
ipcMain.handle("fs:open",(_,p)=>shell.openPath(p));
ipcMain.on("win:minimize",e=>BrowserWindow.fromWebContents(e.sender)?.minimize());
ipcMain.on("win:maximize",e=>{const w=BrowserWindow.fromWebContents(e.sender);w?.isMaximized()?w.unmaximize():w?.maximize()});
ipcMain.on("win:close",e=>BrowserWindow.fromWebContents(e.sender)?.close());
app.whenReady().then(createWindow);
app.on("window-all-closed",()=>app.quit());
MEOF

cat > "$DIR/preload.js" << 'PEOF'
const{contextBridge,ipcRenderer}=require("electron");
contextBridge.exposeInMainWorld("electronAPI",{
  readdir:p=>ipcRenderer.invoke("fs:readdir",p),
  homedir:()=>ipcRenderer.invoke("fs:homedir"),
  startpath:()=>ipcRenderer.invoke("fs:startpath"),
  openFile:p=>ipcRenderer.invoke("fs:open",p),
  minimize:()=>ipcRenderer.send("win:minimize"),
  maximize:()=>ipcRenderer.send("win:maximize"),
  close:()=>ipcRenderer.send("win:close")
});
PEOF

cat > "$DIR/src/main.jsx" << 'REOF'
import React from "react";import ReactDOM from "react-dom/client";import App from "./App.jsx";
ReactDOM.createRoot(document.getElementById("root")).render(<React.StrictMode><App/></React.StrictMode>);
REOF

ok "Project files written"

log "Writing App.jsx..."
python3 - << 'PYEOF'
import json, os
content = "import { useState, useEffect, useCallback, useRef } from \"react\";\n\nconst api = window.electronAPI;\nconst STORAGE_KEY = \"filetree_color\";\nconst DEFAULT_COLOR = \"#b39ddb\";\n\nfunction loadColor() {\n  try { return localStorage.getItem(STORAGE_KEY) || DEFAULT_COLOR; } catch { return DEFAULT_COLOR; }\n}\nfunction saveColor(c) {\n  try { localStorage.setItem(STORAGE_KEY, c); } catch {}\n}\n\nfunction FolderIcon({ color, open }) {\n  return (\n    <svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" style={{ flexShrink: 0 }}>\n      <path d=\"M2 6C2 4.9 2.9 4 4 4H9.17C9.7 4 10.21 4.21 10.59 4.59L12 6H20C21.1 6 22 6.9 22 8V18C22 19.1 21.1 20 20 20H4C2.9 20 2 19.1 2 18V6Z\"\n        fill={open ? color + \"33\" : color + \"22\"} stroke={color} strokeWidth=\"1.5\" strokeLinejoin=\"round\"/>\n      {open && <path d=\"M2 10H22\" stroke={color} strokeWidth=\"1.2\" strokeOpacity=\"0.5\"/>}\n    </svg>\n  );\n}\n\nfunction FileIcon() {\n  return (\n    <svg width=\"14\" height=\"14\" viewBox=\"0 0 24 24\" fill=\"none\" style={{ flexShrink: 0 }}>\n      <path d=\"M13 2H6C4.9 2 4 2.9 4 4V20C4 21.1 4.9 22 6 22H18C19.1 22 20 21.1 20 20V9L13 2Z\"\n        fill=\"#ffffff0d\" stroke=\"#666\" strokeWidth=\"1.5\" strokeLinejoin=\"round\"/>\n      <path d=\"M13 2V9H20\" stroke=\"#666\" strokeWidth=\"1.5\" strokeLinecap=\"round\" strokeLinejoin=\"round\"/>\n    </svg>\n  );\n}\n\nfunction ChevronIcon({ open }) {\n  return (\n    <svg width=\"9\" height=\"9\" viewBox=\"0 0 10 10\" fill=\"none\"\n      style={{ flexShrink: 0, transition: \"transform 0.15s\", transform: open ? \"rotate(90deg)\" : \"rotate(0deg)\" }}>\n      <path d=\"M3 2L7 5L3 8\" stroke=\"#555\" strokeWidth=\"1.5\" strokeLinecap=\"round\" strokeLinejoin=\"round\"/>\n    </svg>\n  );\n}\n\nfunction TBtn({ title, onClick, children, style }) {\n  return (\n    <button title={title} onClick={onClick} style={{\n      background: \"transparent\", border: \"none\", cursor: \"pointer\", padding: \"4px\",\n      display: \"flex\", alignItems: \"center\", color: \"#666\", borderRadius: \"3px\",\n      transition: \"color 0.1s\", WebkitAppRegion: \"no-drag\", ...style\n    }}\n      onMouseEnter={e => e.currentTarget.style.color = \"#bbb\"}\n      onMouseLeave={e => e.currentTarget.style.color = style?.color || \"#666\"}>\n      {children}\n    </button>\n  );\n}\n\n// \u041f\u043e\u043b\u043d\u044b\u0439 \u043f\u043e\u0438\u0441\u043a \u043f\u043e \u0432\u0441\u0435\u0439 \u0444\u0430\u0439\u043b\u043e\u0432\u043e\u0439 \u0441\u0438\u0441\u0442\u0435\u043c\u0435 (BFS, \u0431\u0435\u0437 \u043e\u0433\u0440\u0430\u043d\u0438\u0447\u0435\u043d\u0438\u044f \u0433\u043b\u0443\u0431\u0438\u043d\u044b)\nasync function searchAll(rootPath, query) {\n  const results = [];\n  const q = lowerQuery = query.toLowerCase();\n  // \u041e\u0447\u0435\u0440\u0435\u0434\u044c \u043f\u0430\u043f\u043e\u043a \u0434\u043b\u044f \u043e\u0431\u0445\u043e\u0434\u0430\n  const queue = [rootPath];\n  const visited = new Set();\n\n  while (queue.length > 0) {\n    // \u041e\u0431\u0440\u0430\u0431\u0430\u0442\u044b\u0432\u0430\u0435\u043c \u0431\u0430\u0442\u0447\u0430\u043c\u0438 \u0447\u0442\u043e\u0431\u044b \u043d\u0435 \u0431\u043b\u043e\u043a\u0438\u0440\u043e\u0432\u0430\u0442\u044c UI\n    const batch = queue.splice(0, 20);\n    await Promise.all(batch.map(async (dirPath) => {\n      if (visited.has(dirPath)) return;\n      visited.add(dirPath);\n      const items = await api?.readdir(dirPath) ?? [];\n      for (const item of items) {\n        if (item.name.toLowerCase().includes(lowerQuery)) {\n          results.push(item);\n        }\n        if (item.type === \"folder\") {\n          queue.push(item.path);\n        }\n      }\n    }));\n  }\n  return results;\n}\n\nfunction TreeNode({ node, depth, color, onNavigate }) {\n  const [open, setOpen] = useState(false);\n  const [children, setChildren] = useState(null);\n  const isFolder = node.type === \"folder\";\n\n  const handleClick = useCallback(async () => {\n    if (!isFolder) { api?.openFile(node.path); return; }\n    if (!open && children === null) {\n      const items = await api?.readdir(node.path) ?? [];\n      setChildren([...items].sort((a, b) =>\n        a.type === b.type ? a.name.localeCompare(b.name) : a.type === \"folder\" ? -1 : 1\n      ));\n    }\n    setOpen(o => !o);\n  }, [isFolder, open, children, node.path]);\n\n  return (\n    <div>\n      <div style={{\n        display: \"flex\", alignItems: \"center\", gap: \"5px\",\n        padding: `3px 8px 3px ${8 + depth * 14}px`,\n        cursor: \"pointer\", borderRadius: \"4px\", userSelect: \"none\",\n        fontSize: \"12.5px\", color: \"#ccc\", transition: \"background 0.1s\",\n        WebkitAppRegion: \"no-drag\"\n      }}\n        onClick={handleClick}\n        onDoubleClick={() => isFolder && onNavigate?.(node.path)}\n        onMouseEnter={e => e.currentTarget.style.background = \"#ffffff0d\"}\n        onMouseLeave={e => e.currentTarget.style.background = \"transparent\"}>\n        {isFolder\n          ? <><ChevronIcon open={open}/><FolderIcon color={color} open={open}/></>\n          : <><span style={{ width: 9 }}/><FileIcon/></>}\n        <span style={{ marginLeft: 2, overflow: \"hidden\", textOverflow: \"ellipsis\", whiteSpace: \"nowrap\" }}>\n          {node.name}\n        </span>\n      </div>\n      {isFolder && open && children?.map((child, i) => (\n        <TreeNode key={i} node={child} depth={depth + 1} color={color} onNavigate={onNavigate}/>\n      ))}\n    </div>\n  );\n}\n\n// \u041a\u043b\u0438\u043a\u0430\u0431\u0435\u043b\u044c\u043d\u044b\u0435 \u0445\u043b\u0435\u0431\u043d\u044b\u0435 \u043a\u0440\u043e\u0448\u043a\u0438 \u043f\u0443\u0442\u0438\nfunction Breadcrumbs({ path, onNavigate }) {\n  if (!path) return null;\n  const home = path.match(/^\\/home\\/[^/]+/)?.[0] || \"\";\n  const parts = path.split(\"/\").filter(Boolean);\n  // \u0421\u0442\u0440\u043e\u0438\u043c \u0441\u0435\u0433\u043c\u0435\u043d\u0442\u044b: [{label, fullPath}]\n  const segments = parts.map((part, i) => ({\n    label: part,\n    fullPath: \"/\" + parts.slice(0, i + 1).join(\"/\")\n  }));\n  // \u0414\u043e\u0431\u0430\u0432\u043b\u044f\u0435\u043c \u043a\u043e\u0440\u0435\u043d\u044c\n  segments.unshift({ label: \"/\", fullPath: \"/\" });\n\n  return (\n    <div style={{\n      display: \"flex\", alignItems: \"center\", flexWrap: \"nowrap\",\n      overflow: \"hidden\", gap: \"1px\", WebkitAppRegion: \"no-drag\"\n    }}>\n      {segments.map((seg, i) => (\n        <span key={i} style={{ display: \"flex\", alignItems: \"center\", flexShrink: i < segments.length - 3 ? 1 : 0 }}>\n          {i > 0 && <span style={{ color: \"#333\", margin: \"0 1px\", fontSize: \"10px\" }}>/</span>}\n          <span\n            onClick={() => onNavigate(seg.fullPath)}\n            style={{\n              color: i === segments.length - 1 ? \"#aaa\" : \"#555\",\n              fontSize: \"11px\",\n              cursor: \"pointer\",\n              padding: \"1px 2px\",\n              borderRadius: \"3px\",\n              whiteSpace: \"nowrap\",\n              overflow: \"hidden\",\n              textOverflow: \"ellipsis\",\n              maxWidth: i < segments.length - 2 ? \"60px\" : \"none\",\n              transition: \"color 0.1s\",\n            }}\n            onMouseEnter={e => e.currentTarget.style.color = \"#fff\"}\n            onMouseLeave={e => e.currentTarget.style.color = i === segments.length - 1 ? \"#aaa\" : \"#555\"}\n          >\n            {seg.label}\n          </span>\n        </span>\n      ))}\n    </div>\n  );\n}\n\n// \u041a\u0430\u0441\u0442\u043e\u043c\u043d\u0430\u044f \u043a\u043d\u043e\u043f\u043a\u0430-\u043a\u0440\u0443\u0436\u043e\u043a \u0432\u044b\u0431\u043e\u0440\u0430 \u0446\u0432\u0435\u0442\u0430\nfunction ColorButton({ color, onChange }) {\n  const inputRef = useRef(null);\n  return (\n    <div\n      title=\"\u0426\u0432\u0435\u0442 \u043f\u0430\u043f\u043e\u043a\"\n      onClick={() => inputRef.current?.click()}\n      style={{\n        width: \"16px\", height: \"16px\", borderRadius: \"50%\",\n        background: color, cursor: \"pointer\", flexShrink: 0,\n        boxShadow: `0 0 0 2px #ffffff22`,\n        WebkitAppRegion: \"no-drag\", position: \"relative\"\n      }}>\n      <input\n        ref={inputRef}\n        type=\"color\"\n        value={color}\n        onChange={e => onChange(e.target.value)}\n        style={{ opacity: 0, position: \"absolute\", width: 0, height: 0, pointerEvents: \"none\" }}\n      />\n    </div>\n  );\n}\n\nexport default function App() {\n  const [color, setColor] = useState(loadColor);\n  const [currentPath, setCurrentPath] = useState(null);\n  const [tree, setTree] = useState([]);\n  const [search, setSearch] = useState(\"\");\n  const [showSearch, setShowSearch] = useState(false);\n  const [searchResults, setSearchResults] = useState(null);\n  const [searching, setSearching] = useState(false);\n\n  const handleColorChange = (c) => {\n    setColor(c);\n    saveColor(c);\n  };\n\n  const loadDir = useCallback(async (dirPath) => {\n    const items = await api?.readdir(dirPath) ?? [];\n    setTree([...items].sort((a, b) =>\n      a.type === b.type ? a.name.localeCompare(b.name) : a.type === \"folder\" ? -1 : 1\n    ));\n    setCurrentPath(dirPath);\n    setSearch(\"\");\n    setSearchResults(null);\n  }, []);\n\n  useEffect(() => {\n    (async () => {\n      const start = await api?.startpath?.() ?? await api?.homedir() ?? \"/home\";\n      loadDir(start);\n    })();\n  }, []);\n\n  // \u041f\u043e\u0438\u0441\u043a \u0441 \u0437\u0430\u0434\u0435\u0440\u0436\u043a\u043e\u0439\n  useEffect(() => {\n    if (!search.trim()) { setSearchResults(null); return; }\n    setSearching(true);\n    const timer = setTimeout(async () => {\n      const results = await searchAll(currentPath, search.trim());\n      setSearchResults(results);\n      setSearching(false);\n    }, 300);\n    return () => clearTimeout(timer);\n  }, [search, currentPath]);\n\n  const goUp = () => {\n    if (!currentPath || currentPath === \"/\") return;\n    const parent = currentPath.split(\"/\").slice(0, -1).join(\"/\") || \"/\";\n    loadDir(parent);\n  };\n\n  const displayItems = searchResults ?? tree;\n\n  return (\n    <div style={{\n      background: \"#1e1e2e\", height: \"100vh\",\n      fontFamily: \"'JetBrains Mono','Fira Mono',monospace\",\n      display: \"flex\", flexDirection: \"column\", overflow: \"hidden\"\n    }}>\n      {/* \u0417\u0430\u0433\u043e\u043b\u043e\u0432\u043e\u043a */}\n      <div style={{\n        background: \"#13131f\", borderBottom: \"1px solid #ffffff0f\",\n        padding: \"6px 8px\", display: \"flex\", alignItems: \"center\",\n        justifyContent: \"space-between\", WebkitAppRegion: \"drag\", flexShrink: 0, gap: \"6px\"\n      }}>\n        {/* \u041b\u0435\u0432\u044b\u0435 \u043a\u043d\u043e\u043f\u043a\u0438 */}\n        <div style={{ display: \"flex\", alignItems: \"center\", gap: \"1px\", flexShrink: 0 }}>\n          <TBtn title=\"\u0412\u0432\u0435\u0440\u0445\" onClick={goUp}>\n            <svg width=\"14\" height=\"14\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" strokeWidth=\"1.8\" strokeLinecap=\"round\" strokeLinejoin=\"round\">\n              <polyline points=\"18 15 12 9 6 15\"/>\n            </svg>\n          </TBtn>\n          <TBtn title=\"\u041e\u0431\u043d\u043e\u0432\u0438\u0442\u044c\" onClick={() => currentPath && loadDir(currentPath)}>\n            <svg width=\"14\" height=\"14\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" strokeWidth=\"1.8\" strokeLinecap=\"round\" strokeLinejoin=\"round\">\n              <polyline points=\"23 4 23 10 17 10\"/>\n              <polyline points=\"1 20 1 14 7 14\"/>\n              <path d=\"M3.51 9a9 9 0 0114.36-3.36L23 10M1 14l5.13 4.36A9 9 0 0020.49 15\"/>\n            </svg>\n          </TBtn>\n          <TBtn title=\"\u041f\u043e\u0438\u0441\u043a\" onClick={() => setShowSearch(s => !s)}>\n            <svg width=\"14\" height=\"14\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" strokeWidth=\"1.8\" strokeLinecap=\"round\" strokeLinejoin=\"round\">\n              <circle cx=\"11\" cy=\"11\" r=\"7\"/>\n              <line x1=\"21\" y1=\"21\" x2=\"16.65\" y2=\"16.65\"/>\n            </svg>\n          </TBtn>\n        </div>\n\n        {/* \u0425\u043b\u0435\u0431\u043d\u044b\u0435 \u043a\u0440\u043e\u0448\u043a\u0438 \u2014 \u043f\u043e\u043b\u043d\u044b\u0439 \u043f\u0443\u0442\u044c */}\n        <div style={{ flex: 1, overflow: \"hidden\", minWidth: 0 }}>\n          <Breadcrumbs path={currentPath} onNavigate={loadDir}/>\n        </div>\n\n        {/* \u041f\u0440\u0430\u0432\u044b\u0435 \u043a\u043d\u043e\u043f\u043a\u0438 */}\n        <div style={{ display: \"flex\", alignItems: \"center\", gap: \"3px\", flexShrink: 0 }}>\n          <ColorButton color={color} onChange={handleColorChange}/>\n          <div style={{ width: \"1px\", height: \"12px\", background: \"#ffffff10\", margin: \"0 2px\" }}/>\n          <TBtn title=\"\u0421\u0432\u0435\u0440\u043d\u0443\u0442\u044c\" onClick={() => api?.minimize()}>\n            <svg width=\"12\" height=\"12\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" strokeWidth=\"2\" strokeLinecap=\"round\">\n              <line x1=\"5\" y1=\"12\" x2=\"19\" y2=\"12\"/>\n            </svg>\n          </TBtn>\n          <TBtn title=\"\u0420\u0430\u0437\u0432\u0435\u0440\u043d\u0443\u0442\u044c\" onClick={() => api?.maximize()}>\n            <svg width=\"12\" height=\"12\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" strokeWidth=\"2\" strokeLinecap=\"round\" strokeLinejoin=\"round\">\n              <rect x=\"4\" y=\"4\" width=\"16\" height=\"16\" rx=\"1\"/>\n            </svg>\n          </TBtn>\n          <TBtn title=\"\u0417\u0430\u043a\u0440\u044b\u0442\u044c\" onClick={() => api?.close()} style={{ color: \"#666\" }}>\n            <svg width=\"12\" height=\"12\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" strokeWidth=\"2\" strokeLinecap=\"round\">\n              <line x1=\"18\" y1=\"6\" x2=\"6\" y2=\"18\"/>\n              <line x1=\"6\" y1=\"6\" x2=\"18\" y2=\"18\"/>\n            </svg>\n          </TBtn>\n        </div>\n      </div>\n\n      {/* \u0421\u0442\u0440\u043e\u043a\u0430 \u043f\u043e\u0438\u0441\u043a\u0430 */}\n      {showSearch && (\n        <div style={{ background: \"#13131f\", borderBottom: \"1px solid #ffffff0f\", padding: \"5px 10px\" }}>\n          <input\n            autoFocus\n            value={search}\n            onChange={e => setSearch(e.target.value)}\n            placeholder=\"\u041f\u043e\u0438\u0441\u043a \u0444\u0430\u0439\u043b\u043e\u0432 \u0438 \u043f\u0430\u043f\u043e\u043a...\"\n            style={{\n              width: \"100%\", background: \"#ffffff08\", border: \"1px solid #ffffff12\",\n              borderRadius: \"4px\", color: \"#ccc\", fontSize: \"12px\",\n              padding: \"4px 8px\", outline: \"none\", fontFamily: \"inherit\"\n            }}\n          />\n        </div>\n      )}\n\n      {/* \u0414\u0435\u0440\u0435\u0432\u043e \u0444\u0430\u0439\u043b\u043e\u0432 */}\n      <div style={{ overflowY: \"auto\", flex: 1, padding: \"4px 0\" }}>\n        {searching && (\n          <div style={{ color: \"#555\", fontSize: \"12px\", padding: \"12px 16px\" }}>\u041f\u043e\u0438\u0441\u043a...</div>\n        )}\n        {!searching && displayItems.length === 0 && (\n          <div style={{ color: \"#444\", fontSize: \"12px\", padding: \"16px\", textAlign: \"center\" }}>\n            {search ? \"\u041d\u0438\u0447\u0435\u0433\u043e \u043d\u0435 \u043d\u0430\u0439\u0434\u0435\u043d\u043e\" : \"\u041f\u0430\u043f\u043a\u0430 \u043f\u0443\u0441\u0442\u0430\"}\n          </div>\n        )}\n        {!searching && displayItems.map((node, i) => (\n          <TreeNode key={node.path || i} node={node} depth={0} color={color} onNavigate={loadDir}/>\n        ))}\n      </div>\n    </div>\n  );\n}\n"
dest = os.path.expanduser("~/.filetree/src/App.jsx")
with open(dest, "w") as f:
    f.write(content)
print("App.jsx OK")
PYEOF

# Install dependencies
if [ ! -f "$VITE_BIN" ]; then
  log "Installing React + Vite..."
  cd "$DIR"
  npm config set registry https://registry.npmmirror.com
  npm install || fail "npm install failed"
  ok "React + Vite installed"
else
  ok "React + Vite -- skip"
fi

if [ ! -f "$ELECTRON_BIN" ]; then
  log "Installing Electron..."
  cd "$DIR"
  npm config set registry https://registry.npmmirror.com
  export ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/"
  npm install electron@28 --save-dev || fail "Cannot install Electron"
  ok "Electron installed"
else
  ok "Electron -- skip"
fi

[ -f "$ELECTRON_BIN" ] || fail "Electron binary not found at $ELECTRON_BIN -- installation failed"

log "Building interface..."
rm -rf "$DIR/dist"
cd "$DIR"
"$VITE_BIN" build --logLevel warn || fail "Build failed"
ok "Build complete"

log "Registering FileTree as default file manager..."

mkdir -p "$HOME/.local/bin"

# filetree wrapper
printf '#!/bin/bash\nexport DISPLAY="${DISPLAY:-:0}"\nif [ -n "$1" ] && [ -d "$1" ]; then\n  exec "%s" "%s" --no-sandbox "$1"\nelse\n  exec "%s" "%s" --no-sandbox\nfi\n' \
  "$ELECTRON_BIN" "$DIR" "$ELECTRON_BIN" "$DIR" > "$WRAPPER"
chmod +x "$WRAPPER"
ok "Wrapper: $WRAPPER"

# fake thunar (xfdesktop may call thunar directly by name)
printf '#!/bin/bash\nexport DISPLAY="${DISPLAY:-:0}"\nfor arg in "$@"; do\n  [[ "$arg" == --* ]] && continue\n  [ -d "$arg" ] && exec "%s" "%s" --no-sandbox "$arg"\ndone\nexec "%s" "%s" --no-sandbox\n' \
  "$ELECTRON_BIN" "$DIR" "$ELECTRON_BIN" "$DIR" > "$THUNAR_WRAPPER"
chmod +x "$THUNAR_WRAPPER"
ok "Fake thunar: $THUNAR_WRAPPER"

# XFCE helper
HELPERS_DIR="$HOME/.local/share/xfce4/helpers"
mkdir -p "$HELPERS_DIR"
printf '[Desktop Entry]\nVersion=1.0\nEncoding=UTF-8\nType=X-XFCE-Helper\nX-XFCE-Helper-Name=FileTree\nX-XFCE-Helper-Category=FileManager\nX-XFCE-Binaries=%s;\nX-XFCE-Commands=%s;\nX-XFCE-CommandsWithParameter=%s "%%s";\nIcon=system-file-manager\nName=FileTree\n' \
  "$WRAPPER" "$WRAPPER" "$WRAPPER" > "$HELPERS_DIR/filetree.desktop"
ok "XFCE helper created"

# helpers.rc
mkdir -p "$HOME/.config/xfce4"
touch "$HOME/.config/xfce4/helpers.rc"
sed -i '/^FileManager=/d' "$HOME/.config/xfce4/helpers.rc"
echo "FileManager=filetree" >> "$HOME/.config/xfce4/helpers.rc"
ok "helpers.rc: FileManager=filetree"

# .desktop
mkdir -p "$HOME/.local/share/applications"
printf '[Desktop Entry]\nVersion=1.0\nName=FileTree\nGenericName=File Manager\nComment=Custom file manager\nExec=%s %%U\nIcon=system-file-manager\nTerminal=false\nType=Application\nCategories=System;FileManager;\nMimeType=inode/directory;x-directory/normal;\nStartupNotify=true\nX-XFCE-Binaries=%s\nX-XFCE-Category=FileManager\n' \
  "$WRAPPER" "$WRAPPER" > "$HOME/.local/share/applications/filetree.desktop"
ok ".desktop created"

# mimeapps.list
touch "$HOME/.config/mimeapps.list"
sed -i '/^inode\/directory=/d;/^x-directory\/normal=/d' "$HOME/.config/mimeapps.list"
grep -q '^\[Default Applications\]' "$HOME/.config/mimeapps.list" || echo '[Default Applications]' >> "$HOME/.config/mimeapps.list"
sed -i '/^\[Default Applications\]/a inode\/directory=filetree.desktop\nx-directory\/normal=filetree.desktop' "$HOME/.config/mimeapps.list"
grep -q '^\[Added Associations\]' "$HOME/.config/mimeapps.list" 2>/dev/null || printf '\n[Added Associations]\n' >> "$HOME/.config/mimeapps.list"
sed -i '/^inode\/directory=filetree/d;/^x-directory\/normal=filetree/d' "$HOME/.config/mimeapps.list"
sed -i '/^\[Added Associations\]/a inode\/directory=filetree.desktop;\nx-directory\/normal=filetree.desktop;' "$HOME/.config/mimeapps.list"
ok "mimeapps.list updated"

command -v xdg-mime &>/dev/null && xdg-mime default filetree.desktop inode/directory 2>/dev/null && ok "xdg-mime updated" || true
command -v gio &>/dev/null && gio mime inode/directory filetree.desktop 2>/dev/null && ok "gio mime updated" || true

# Block Thunar autostart
mkdir -p "$HOME/.config/autostart"
printf '[Desktop Entry]\nType=Application\nName=Thunar\nHidden=true\nX-GNOME-Autostart-enabled=false\n' > "$HOME/.config/autostart/thunar.desktop"
for f in /etc/xdg/autostart/thunar*.desktop; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  cp "$f" "$HOME/.config/autostart/$base" 2>/dev/null || true
  echo "Hidden=true" >> "$HOME/.config/autostart/$base"
done
ok "Thunar autostart blocked"

if command -v xfconf-query &>/dev/null; then
  xfconf-query -c xfce4-mime-settings -p /FileManager -n -t string -s "$WRAPPER" 2>/dev/null \
    || xfconf-query -c xfce4-mime-settings -p /FileManager -s "$WRAPPER" 2>/dev/null || true
  ok "xfconf updated"
fi

for rcfile in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.xprofile"; do
  grep -qF 'local/bin' "$rcfile" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rcfile"
done
export PATH="$HOME/.local/bin:$PATH"

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
xfdesktop --reload 2>/dev/null || true

# Copy wrapper to /usr/local/bin so XFCE finds it regardless of PATH
if command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
  sudo cp "$WRAPPER" /usr/local/bin/filetree
  sudo cp "$THUNAR_WRAPPER" /usr/local/bin/thunar
  sudo chmod +x /usr/local/bin/filetree /usr/local/bin/thunar
  ok "Wrappers copied to /usr/local/bin"
elif [ "$(id -u)" = "0" ]; then
  cp "$WRAPPER" /usr/local/bin/filetree
  cp "$THUNAR_WRAPPER" /usr/local/bin/thunar
  chmod +x /usr/local/bin/filetree /usr/local/bin/thunar
  ok "Wrappers copied to /usr/local/bin"
fi

# Also copy XFCE helper to system-wide location
SYSTEM_HELPERS="/usr/local/share/xfce4/helpers"
if command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
  sudo mkdir -p "$SYSTEM_HELPERS"
  sudo cp "$HOME/.local/share/xfce4/helpers/filetree.desktop" "$SYSTEM_HELPERS/filetree.desktop"
  ok "XFCE helper copied to $SYSTEM_HELPERS"
elif [ "$(id -u)" = "0" ]; then
  mkdir -p "$SYSTEM_HELPERS"
  cp "$HOME/.local/share/xfce4/helpers/filetree.desktop" "$SYSTEM_HELPERS/filetree.desktop"
  ok "XFCE helper copied to $SYSTEM_HELPERS"
fi

ok "Registration complete"

log "Launching FileTree..."
echo ""
echo "========================================"
echo "  FileTree is running! Ctrl+C to stop."
echo "  After first run: logout and login"
echo "  to apply as default file manager."
echo "========================================"
echo ""
export DISPLAY="${DISPLAY:-:0}"
cd "$DIR"
exec "$ELECTRON_BIN" . --no-sandbox
