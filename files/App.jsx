import { useState, useEffect, useCallback, useRef } from "react";

const api = window.electronAPI;
const STORAGE_KEY = "filetree_color";
const SIDEBAR_KEY  = "filetree_sidebar";
const DEFAULT_COLOR = "#b39ddb";

function loadColor() { try { return localStorage.getItem(STORAGE_KEY) || DEFAULT_COLOR; } catch { return DEFAULT_COLOR; } }
function saveColor(c){ try { localStorage.setItem(STORAGE_KEY, c); } catch {} }

// ── Icons ──────────────────────────────────────────────────────────────
function FolderIcon({ color, open }) {
  return (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" style={{ flexShrink:0 }}>
      <path d="M2 6C2 4.9 2.9 4 4 4H9.17C9.7 4 10.21 4.21 10.59 4.59L12 6H20C21.1 6 22 6.9 22 8V18C22 19.1 21.1 20 20 20H4C2.9 20 2 19.1 2 18V6Z"
        fill={open ? color+"33" : color+"22"} stroke={color} strokeWidth="1.5" strokeLinejoin="round"/>
      {open && <path d="M2 10H22" stroke={color} strokeWidth="1.2" strokeOpacity="0.5"/>}
    </svg>
  );
}
function FileIcon() {
  return (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" style={{ flexShrink:0 }}>
      <path d="M13 2H6C4.9 2 4 2.9 4 4V20C4 21.1 4.9 22 6 22H18C19.1 22 20 21.1 20 20V9L13 2Z"
        fill="#ffffff0d" stroke="#555" strokeWidth="1.5" strokeLinejoin="round"/>
      <path d="M13 2V9H20" stroke="#555" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
}
function ChevronIcon({ open }) {
  return (
    <svg width="8" height="8" viewBox="0 0 10 10" fill="none"
      style={{ flexShrink:0, transition:"transform 0.15s", transform: open?"rotate(90deg)":"rotate(0deg)" }}>
      <path d="M3 2L7 5L3 8" stroke="#444" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
}
function TBtn({ title, onClick, children }) {
  return (
    <button title={title} onClick={onClick} style={{
      background:"transparent", border:"none", cursor:"pointer", padding:"4px",
      display:"flex", alignItems:"center", color:"#555", borderRadius:"3px",
      transition:"color 0.1s", WebkitAppRegion:"no-drag"
    }}
      onMouseEnter={e=>e.currentTarget.style.color="#bbb"}
      onMouseLeave={e=>e.currentTarget.style.color="#555"}>
      {children}
    </button>
  );
}

// ── Context Menu ───────────────────────────────────────────────────────
function ContextMenu({ x, y, items, onClose }) {
  const ref = useRef(null);
  useEffect(() => {
    const handler = (e) => { if (ref.current && !ref.current.contains(e.target)) onClose(); };
    setTimeout(() => {
      window.addEventListener("mousedown", handler);
      window.addEventListener("contextmenu", handler);
    }, 0);
    return () => { window.removeEventListener("mousedown", handler); window.removeEventListener("contextmenu", handler); };
  }, [onClose]);

  // Adjust position to stay in viewport
  const style = {
    position:"fixed", zIndex:9999,
    background:"#16161f", border:"1px solid #ffffff18",
    borderRadius:"7px", padding:"4px 0", minWidth:"195px",
    boxShadow:"0 10px 40px #00000090",
    fontFamily:"'JetBrains Mono','Fira Mono',monospace",
    left: Math.min(x, window.innerWidth - 210),
    top:  Math.min(y, window.innerHeight - items.length * 30 - 20),
  };

  return (
    <div ref={ref} style={style} onContextMenu={e=>e.preventDefault()}>
      {items.map((item, i) =>
        item.separator
          ? <div key={i} style={{ height:"1px", background:"#ffffff10", margin:"3px 0" }}/>
          : (
            <div key={i} onClick={()=>{ item.action(); onClose(); }} style={{
              padding:"6px 14px", fontSize:"12px",
              color: item.danger ? "#ff7070" : "#ccc",
              cursor:"pointer", userSelect:"none"
            }}
              onMouseEnter={e=>e.currentTarget.style.background="#ffffff0d"}
              onMouseLeave={e=>e.currentTarget.style.background="transparent"}>
              {item.label}
            </div>
          )
      )}
    </div>
  );
}

// ── Sidebar ────────────────────────────────────────────────────────────
function SidebarIcon({ type }) {
  const props = { width:13, height:13, viewBox:"0 0 24 24", fill:"none",
    stroke:"currentColor", strokeWidth:"1.8", strokeLinecap:"round", strokeLinejoin:"round",
    style:{flexShrink:0} };
  if (type==="home")      return <svg {...props}><path d="M3 9.5L12 3l9 6.5V20a1 1 0 01-1 1H4a1 1 0 01-1-1V9.5z"/><path d="M9 21V12h6v9"/></svg>;
  if (type==="desktop")   return <svg {...props}><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/></svg>;
  if (type==="documents") return <svg {...props}><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="8" y1="13" x2="16" y2="13"/><line x1="8" y1="17" x2="16" y2="17"/></svg>;
  if (type==="downloads") return <svg {...props}><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>;
  if (type==="music")     return <svg {...props}><path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/></svg>;
  if (type==="pictures")  return <svg {...props}><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>;
  if (type==="videos")    return <svg {...props}><polygon points="23 7 16 12 23 17 23 7"/><rect x="1" y="5" width="15" height="14" rx="2"/></svg>;
  return <svg {...props}><path d="M22 19a2 2 0 01-2 2H4a2 2 0 01-2-2V5a2 2 0 012-2h5l2 3h9a2 2 0 012 2z"/></svg>;
}

function Sidebar({ currentPath, onNavigate, color, home }) {
  const [contextMenu, setContextMenu] = useState(null);
  const [favorites, setFavorites] = useState(() => {
    try {
      const saved = localStorage.getItem(SIDEBAR_KEY);
      return saved ? JSON.parse(saved) : null;
    } catch { return null; }
  });

  // Build default favorites from home
  const defaultFavs = home ? [
    { name:"Домашняя", type:"home",      path: home },
    { name:"Рабочий стол", type:"desktop",  path: home+"/Desktop" },
    { name:"Документы",    type:"documents",path: home+"/Documents" },
    { name:"Загрузки",     type:"downloads",path: home+"/Downloads" },
    { name:"Музыка",       type:"music",    path: home+"/Music" },
    { name:"Изображения",  type:"pictures", path: home+"/Pictures" },
    { name:"Видео",        type:"videos",   path: home+"/Videos" },
  ] : [];

  const favs = favorites || defaultFavs;

  const saveFavs = (f) => {
    setFavorites(f);
    localStorage.setItem(SIDEBAR_KEY, JSON.stringify(f));
  };

  const handleContextMenu = (e, item) => {
    e.preventDefault();
    e.stopPropagation();
    setContextMenu({
      x: e.clientX, y: e.clientY,
      items: [
        { label:"Открыть в новой вкладке", action:()=> api?.newWindow(item.path) },
        { label:"Показать содержащую папку", action:()=> onNavigate(item.path.split("/").slice(0,-1).join("/")||"/") },
        { separator:true },
        { label:"Удалить из бокового меню", action:()=> saveFavs(favs.filter(f=>f.path!==item.path)), danger:true },
      ]
    });
  };

  return (
    <div style={{
      width:"155px", flexShrink:0, background:"#13131f",
      borderRight:"1px solid #ffffff08", display:"flex", flexDirection:"column",
      overflowY:"auto", overflowX:"hidden"
    }}>
      <div style={{ padding:"10px 8px 4px 10px", fontSize:"10px", color:"#444", letterSpacing:"0.08em", userSelect:"none" }}>
        ИЗБРАННОЕ
      </div>
      {favs.map((item, i) => {
        const isActive = currentPath === item.path;
        return (
          <div key={i}
            onClick={()=>onNavigate(item.path)}
            onContextMenu={e=>handleContextMenu(e, item)}
            draggable
            onDragStart={e=>{ e.dataTransfer.setData("text/plain", item.path); e.dataTransfer.effectAllowed="move"; }}
            style={{
              display:"flex", alignItems:"center", gap:"7px",
              padding:"5px 8px 5px 10px", cursor:"pointer",
              borderRadius:"5px", margin:"1px 4px",
              background: isActive ? "#ffffff0f" : "transparent",
              color: isActive ? "#ccc" : "#666",
              fontSize:"12px", userSelect:"none", transition:"background 0.1s"
            }}
            onMouseEnter={e=>{ if(!isActive) e.currentTarget.style.background="#ffffff08"; }}
            onMouseLeave={e=>{ if(!isActive) e.currentTarget.style.background="transparent"; }}>
            <SidebarIcon type={item.type}/>
            <span style={{ overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{item.name}</span>
          </div>
        );
      })}
      {contextMenu && (
        <ContextMenu x={contextMenu.x} y={contextMenu.y} items={contextMenu.items} onClose={()=>setContextMenu(null)}/>
      )}
    </div>
  );
}

// ── Breadcrumbs ────────────────────────────────────────────────────────
function Breadcrumbs({ path, onNavigate }) {
  if (!path) return null;
  const parts = path.split("/").filter(Boolean);
  const segments = [{ label:"/", fullPath:"/" },
    ...parts.map((p,i)=>({ label:p, fullPath:"/"+parts.slice(0,i+1).join("/") }))
  ];
  return (
    <div style={{ display:"flex", alignItems:"center", flexWrap:"nowrap",
      overflow:"hidden", gap:"1px", WebkitAppRegion:"no-drag" }}>
      {segments.map((seg,i)=>(
        <span key={i} style={{ display:"flex", alignItems:"center",
          flexShrink: i < segments.length-2 ? 1 : 0 }}>
          {i>0 && <span style={{ color:"#2a2a3a", margin:"0 1px", fontSize:"10px" }}>/</span>}
          <span onClick={()=>onNavigate(seg.fullPath)} style={{
            color: i===segments.length-1 ? "#999" : "#444",
            fontSize:"11px", cursor:"pointer", padding:"1px 2px", borderRadius:"3px",
            whiteSpace:"nowrap", overflow:"hidden", textOverflow:"ellipsis",
            maxWidth: i < segments.length-2 ? "55px" : "none", transition:"color 0.1s"
          }}
            onMouseEnter={e=>e.currentTarget.style.color="#fff"}
            onMouseLeave={e=>e.currentTarget.style.color=i===segments.length-1?"#999":"#444"}>
            {seg.label}
          </span>
        </span>
      ))}
    </div>
  );
}

// ── Color Button ───────────────────────────────────────────────────────
function ColorButton({ color, onChange }) {
  const inputRef = useRef(null);
  return (
    <div title="Цвет папок" onClick={()=>inputRef.current?.click()} style={{
      width:"13px", height:"13px", borderRadius:"50%", background:color,
      cursor:"pointer", flexShrink:0, boxShadow:"0 0 0 1.5px #ffffff20",
      WebkitAppRegion:"no-drag", position:"relative"
    }}>
      <input ref={inputRef} type="color" value={color}
        onChange={e=>onChange(e.target.value)}
        style={{ opacity:0, position:"absolute", width:0, height:0, pointerEvents:"none" }}/>
    </div>
  );
}

// ── BFS Search ─────────────────────────────────────────────────────────
async function searchAll(rootPath, query) {
  const results = [], lq = query.toLowerCase();
  const queue = [rootPath], visited = new Set();
  while (queue.length > 0) {
    const batch = queue.splice(0, 20);
    await Promise.all(batch.map(async (dirPath) => {
      if (visited.has(dirPath)) return;
      visited.add(dirPath);
      const items = await api?.readdir(dirPath) ?? [];
      for (const item of items) {
        if (item.name.toLowerCase().includes(lq)) results.push(item);
        if (item.type==="folder") queue.push(item.path);
      }
    }));
  }
  return results;
}

// ── Tree Node ──────────────────────────────────────────────────────────
function TreeNode({ node, depth, color, onNavigate, onRefresh }) {
  const [open, setOpen]         = useState(false);
  const [children, setChildren] = useState(null);
  const [loading, setLoading]   = useState(false);
  const [dragOver, setDragOver] = useState(false);
  const [ctxMenu, setCtxMenu]   = useState(null);
  const isFolder = node.type === "folder";

  const loadChildren = async () => {
    setLoading(true);
    const items = await api?.readdir(node.path) ?? [];
    setChildren([...items].sort((a,b)=>
      a.type===b.type ? a.name.localeCompare(b.name) : a.type==="folder"?-1:1));
    setLoading(false);
  };

  const handleClick = useCallback(async () => {
    if (!isFolder) { api?.openFile(node.path); return; }
    if (!open && children===null) await loadChildren();
    setOpen(o=>!o);
  }, [isFolder, open, children, node.path]);

  const handleDblClick = () => { if (isFolder) onNavigate?.(node.path); };

  // Drag source
  const handleDragStart = (e) => {
    e.stopPropagation();
    e.dataTransfer.setData("text/plain", node.path);
    e.dataTransfer.effectAllowed = "move";
  };

  // Drop target (folders only)
  const handleDragOver = (e) => {
    if (!isFolder) return;
    e.preventDefault(); e.stopPropagation();
    e.dataTransfer.dropEffect = "move";
    setDragOver(true);
  };
  const handleDragLeave = () => setDragOver(false);
  const handleDrop = async (e) => {
    e.preventDefault(); e.stopPropagation();
    setDragOver(false);
    const src = e.dataTransfer.getData("text/plain");
    if (!src || src===node.path) return;
    await api?.move(src, node.path);
    onRefresh?.();
  };

  // Context menu
  const handleContextMenu = (e) => {
    e.preventDefault(); e.stopPropagation();
    setCtxMenu({ x:e.clientX, y:e.clientY });
  };

  const ctxItems = [
    { label:"Открыть в новой вкладке", action:()=> api?.newWindow(isFolder ? node.path : undefined) },
    { separator:true },
    { label:"Удалить", danger:true, action: async ()=>{
      if (confirm(`Удалить "${node.name}" навсегда?`)) { await api?.deleteItem(node.path); onRefresh?.(); }
    }},
    { separator:true },
    { label:"Сжать", action: async ()=>{ await api?.compress(node.path); onRefresh?.(); } },
    { label:"Дублировать", action: async ()=>{ await api?.duplicate(node.path); onRefresh?.(); } },
    { label:"Скопировать путь", action:()=> api?.copyPath(node.path) },
  ];

  return (
    <div>
      <div
        draggable
        onDragStart={handleDragStart}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onClick={handleClick}
        onDoubleClick={handleDblClick}
        onContextMenu={handleContextMenu}
        style={{
          display:"flex", alignItems:"center", gap:"5px",
          padding:`3px 8px 3px ${8+depth*14}px`,
          cursor:"pointer", borderRadius:"4px", userSelect:"none",
          fontSize:"12.5px", color:"#ccc", transition:"background 0.1s",
          WebkitAppRegion:"no-drag",
          background: dragOver ? "#b39ddb18" : "transparent",
          outline: dragOver ? "1px solid #b39ddb44" : "none",
        }}
        onMouseEnter={e=>{ if(!dragOver) e.currentTarget.style.background="#ffffff0d"; }}
        onMouseLeave={e=>{ if(!dragOver) e.currentTarget.style.background="transparent"; }}>
        {isFolder
          ? <><ChevronIcon open={open}/><FolderIcon color={color} open={open}/></>
          : <><span style={{width:8}}/><FileIcon/></>}
        <span style={{ marginLeft:2, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap", flex:1 }}>
          {node.name}
        </span>
        {loading && <span style={{ color:"#333", fontSize:"10px" }}>…</span>}
      </div>
      {isFolder && open && children?.map((child,i)=>(
        <TreeNode key={child.path||i} node={child} depth={depth+1}
          color={color} onNavigate={onNavigate} onRefresh={onRefresh}/>
      ))}
      {ctxMenu && (
        <ContextMenu x={ctxMenu.x} y={ctxMenu.y} items={ctxItems} onClose={()=>setCtxMenu(null)}/>
      )}
    </div>
  );
}

// ── App ────────────────────────────────────────────────────────────────
export default function App() {
  const [color, setColor]             = useState(loadColor);
  const [currentPath, setCurrentPath] = useState(null);
  const [home, setHome]               = useState(null);
  const [tree, setTree]               = useState([]);
  const [search, setSearch]           = useState("");
  const [showSearch, setShowSearch]   = useState(false);
  const [searchResults, setSearchResults] = useState(null);
  const [searching, setSearching]     = useState(false);
  const [refresh, setRefresh]         = useState(0);

  const handleColorChange = (c) => { setColor(c); saveColor(c); };

  const loadDir = useCallback(async (dirPath) => {
    const items = await api?.readdir(dirPath) ?? [];
    setTree([...items].sort((a,b)=>
      a.type===b.type ? a.name.localeCompare(b.name) : a.type==="folder"?-1:1));
    setCurrentPath(dirPath);
    setSearch(""); setSearchResults(null);
  }, []);

  const doRefresh = useCallback(()=>{ if(currentPath) loadDir(currentPath); }, [currentPath, loadDir]);

  useEffect(()=>{
    (async()=>{
      const h = await api?.homedir() ?? "/home";
      setHome(h);
      const start = await api?.startpath?.() ?? h;
      loadDir(start);
    })();
  }, []);

  useEffect(()=>{ if(refresh>0) doRefresh(); }, [refresh]);

  // BFS search
  useEffect(()=>{
    if (!search.trim()) { setSearchResults(null); return; }
    setSearching(true);
    const t = setTimeout(async()=>{
      const r = await searchAll(currentPath, search.trim());
      setSearchResults(r); setSearching(false);
    }, 300);
    return ()=>clearTimeout(t);
  }, [search, currentPath]);

  const goUp = ()=>{
    if (!currentPath || currentPath==="/") return;
    loadDir(currentPath.split("/").slice(0,-1).join("/")||"/");
  };

  const displayItems = searchResults ?? tree;

  return (
    <div style={{ background:"#1e1e2e", height:"100vh",
      fontFamily:"'JetBrains Mono','Fira Mono',monospace",
      display:"flex", flexDirection:"column", overflow:"hidden" }}>

      {/* Title bar */}
      <div style={{ background:"#0f0f1a", borderBottom:"1px solid #ffffff08",
        padding:"5px 8px", display:"flex", alignItems:"center",
        justifyContent:"space-between", WebkitAppRegion:"drag", flexShrink:0, gap:"6px" }}>
        <div style={{ display:"flex", alignItems:"center", gap:"1px", flexShrink:0 }}>
          <TBtn title="Вверх" onClick={goUp}>
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><polyline points="18 15 12 9 6 15"/></svg>
          </TBtn>
          <TBtn title="Обновить" onClick={doRefresh}>
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0114.36-3.36L23 10M1 14l5.13 4.36A9 9 0 0020.49 15"/></svg>
          </TBtn>
          <TBtn title="Поиск" onClick={()=>setShowSearch(s=>!s)}>
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
          </TBtn>
        </div>
        <div style={{ flex:1, overflow:"hidden", minWidth:0 }}>
          <Breadcrumbs path={currentPath} onNavigate={loadDir}/>
        </div>
        <div style={{ display:"flex", alignItems:"center", gap:"3px", flexShrink:0 }}>
          <ColorButton color={color} onChange={handleColorChange}/>
          <div style={{ width:"1px", height:"11px", background:"#ffffff0d", margin:"0 2px" }}/>
          <TBtn title="Свернуть" onClick={()=>api?.minimize()}>
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><line x1="5" y1="12" x2="19" y2="12"/></svg>
          </TBtn>
          <TBtn title="Развернуть" onClick={()=>api?.maximize()}>
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="4" y="4" width="16" height="16" rx="1"/></svg>
          </TBtn>
          <TBtn title="Закрыть" onClick={()=>api?.close()}>
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </TBtn>
        </div>
      </div>

      {/* Search bar */}
      {showSearch && (
        <div style={{ background:"#0f0f1a", borderBottom:"1px solid #ffffff08", padding:"4px 10px" }}>
          <input autoFocus value={search} onChange={e=>setSearch(e.target.value)}
            placeholder="Поиск файлов и папок..."
            style={{ width:"100%", background:"#ffffff06", border:"1px solid #ffffff10",
              borderRadius:"4px", color:"#ccc", fontSize:"12px",
              padding:"4px 8px", outline:"none", fontFamily:"inherit" }}/>
        </div>
      )}

      {/* Body: sidebar + tree */}
      <div style={{ display:"flex", flex:1, overflow:"hidden" }}>
        <Sidebar currentPath={currentPath} onNavigate={loadDir} color={color} home={home}/>

        {/* File tree */}
        <div style={{ overflowY:"auto", flex:1, padding:"4px 0" }}>
          {searching && <div style={{ color:"#444", fontSize:"12px", padding:"12px 16px" }}>Поиск...</div>}
          {!searching && displayItems.length===0 && (
            <div style={{ color:"#333", fontSize:"12px", padding:"16px", textAlign:"center" }}>
              {search ? "Ничего не найдено" : "Папка пуста"}
            </div>
          )}
          {!searching && displayItems.map((node,i)=>(
            <TreeNode key={node.path||i} node={node} depth={0}
              color={color} onNavigate={loadDir} onRefresh={doRefresh}/>
          ))}
        </div>
      </div>
    </div>
  );
}
