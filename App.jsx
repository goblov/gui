import { useState, useEffect, useCallback, useRef } from "react";

const api = window.electronAPI;
const STORAGE_KEY = "filetree_color";
const DEFAULT_COLOR = "#b39ddb";

function loadColor() {
  try { return localStorage.getItem(STORAGE_KEY) || DEFAULT_COLOR; } catch { return DEFAULT_COLOR; }
}
function saveColor(c) {
  try { localStorage.setItem(STORAGE_KEY, c); } catch {}
}

function FolderIcon({ color, open }) {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" style={{ flexShrink: 0 }}>
      <path d="M2 6C2 4.9 2.9 4 4 4H9.17C9.7 4 10.21 4.21 10.59 4.59L12 6H20C21.1 6 22 6.9 22 8V18C22 19.1 21.1 20 20 20H4C2.9 20 2 19.1 2 18V6Z"
        fill={open ? color + "33" : color + "22"} stroke={color} strokeWidth="1.5" strokeLinejoin="round"/>
      {open && <path d="M2 10H22" stroke={color} strokeWidth="1.2" strokeOpacity="0.5"/>}
    </svg>
  );
}

function FileIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" style={{ flexShrink: 0 }}>
      <path d="M13 2H6C4.9 2 4 2.9 4 4V20C4 21.1 4.9 22 6 22H18C19.1 22 20 21.1 20 20V9L13 2Z"
        fill="#ffffff0d" stroke="#666" strokeWidth="1.5" strokeLinejoin="round"/>
      <path d="M13 2V9H20" stroke="#666" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
}

function ChevronIcon({ open }) {
  return (
    <svg width="9" height="9" viewBox="0 0 10 10" fill="none"
      style={{ flexShrink: 0, transition: "transform 0.15s", transform: open ? "rotate(90deg)" : "rotate(0deg)" }}>
      <path d="M3 2L7 5L3 8" stroke="#555" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
}

function TBtn({ title, onClick, children, style }) {
  return (
    <button title={title} onClick={onClick} style={{
      background: "transparent", border: "none", cursor: "pointer", padding: "4px",
      display: "flex", alignItems: "center", color: "#666", borderRadius: "3px",
      transition: "color 0.1s", WebkitAppRegion: "no-drag", ...style
    }}
      onMouseEnter={e => e.currentTarget.style.color = "#bbb"}
      onMouseLeave={e => e.currentTarget.style.color = style?.color || "#666"}>
      {children}
    </button>
  );
}

// Полный поиск по всей файловой системе (BFS, без ограничения глубины)
async function searchAll(rootPath, query) {
  const results = [];
  const q = lowerQuery = query.toLowerCase();
  // Очередь папок для обхода
  const queue = [rootPath];
  const visited = new Set();

  while (queue.length > 0) {
    // Обрабатываем батчами чтобы не блокировать UI
    const batch = queue.splice(0, 20);
    await Promise.all(batch.map(async (dirPath) => {
      if (visited.has(dirPath)) return;
      visited.add(dirPath);
      const items = await api?.readdir(dirPath) ?? [];
      for (const item of items) {
        if (item.name.toLowerCase().includes(lowerQuery)) {
          results.push(item);
        }
        if (item.type === "folder") {
          queue.push(item.path);
        }
      }
    }));
  }
  return results;
}

function TreeNode({ node, depth, color, onNavigate }) {
  const [open, setOpen] = useState(false);
  const [children, setChildren] = useState(null);
  const isFolder = node.type === "folder";

  const handleClick = useCallback(async () => {
    if (!isFolder) { api?.openFile(node.path); return; }
    if (!open && children === null) {
      const items = await api?.readdir(node.path) ?? [];
      setChildren([...items].sort((a, b) =>
        a.type === b.type ? a.name.localeCompare(b.name) : a.type === "folder" ? -1 : 1
      ));
    }
    setOpen(o => !o);
  }, [isFolder, open, children, node.path]);

  return (
    <div>
      <div style={{
        display: "flex", alignItems: "center", gap: "5px",
        padding: `3px 8px 3px ${8 + depth * 14}px`,
        cursor: "pointer", borderRadius: "4px", userSelect: "none",
        fontSize: "12.5px", color: "#ccc", transition: "background 0.1s",
        WebkitAppRegion: "no-drag"
      }}
        onClick={handleClick}
        onDoubleClick={() => isFolder && onNavigate?.(node.path)}
        onMouseEnter={e => e.currentTarget.style.background = "#ffffff0d"}
        onMouseLeave={e => e.currentTarget.style.background = "transparent"}>
        {isFolder
          ? <><ChevronIcon open={open}/><FolderIcon color={color} open={open}/></>
          : <><span style={{ width: 9 }}/><FileIcon/></>}
        <span style={{ marginLeft: 2, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
          {node.name}
        </span>
      </div>
      {isFolder && open && children?.map((child, i) => (
        <TreeNode key={i} node={child} depth={depth + 1} color={color} onNavigate={onNavigate}/>
      ))}
    </div>
  );
}

// Кликабельные хлебные крошки пути
function Breadcrumbs({ path, onNavigate }) {
  if (!path) return null;
  const home = path.match(/^\/home\/[^/]+/)?.[0] || "";
  const parts = path.split("/").filter(Boolean);
  // Строим сегменты: [{label, fullPath}]
  const segments = parts.map((part, i) => ({
    label: part,
    fullPath: "/" + parts.slice(0, i + 1).join("/")
  }));
  // Добавляем корень
  segments.unshift({ label: "/", fullPath: "/" });

  return (
    <div style={{
      display: "flex", alignItems: "center", flexWrap: "nowrap",
      overflow: "hidden", gap: "1px", WebkitAppRegion: "no-drag"
    }}>
      {segments.map((seg, i) => (
        <span key={i} style={{ display: "flex", alignItems: "center", flexShrink: i < segments.length - 3 ? 1 : 0 }}>
          {i > 0 && <span style={{ color: "#333", margin: "0 1px", fontSize: "10px" }}>/</span>}
          <span
            onClick={() => onNavigate(seg.fullPath)}
            style={{
              color: i === segments.length - 1 ? "#aaa" : "#555",
              fontSize: "11px",
              cursor: "pointer",
              padding: "1px 2px",
              borderRadius: "3px",
              whiteSpace: "nowrap",
              overflow: "hidden",
              textOverflow: "ellipsis",
              maxWidth: i < segments.length - 2 ? "60px" : "none",
              transition: "color 0.1s",
            }}
            onMouseEnter={e => e.currentTarget.style.color = "#fff"}
            onMouseLeave={e => e.currentTarget.style.color = i === segments.length - 1 ? "#aaa" : "#555"}
          >
            {seg.label}
          </span>
        </span>
      ))}
    </div>
  );
}

// Кастомная кнопка-кружок выбора цвета
function ColorButton({ color, onChange }) {
  const inputRef = useRef(null);
  return (
    <div
      title="Цвет папок"
      onClick={() => inputRef.current?.click()}
      style={{
        width: "16px", height: "16px", borderRadius: "50%",
        background: color, cursor: "pointer", flexShrink: 0,
        boxShadow: `0 0 0 2px #ffffff22`,
        WebkitAppRegion: "no-drag", position: "relative"
      }}>
      <input
        ref={inputRef}
        type="color"
        value={color}
        onChange={e => onChange(e.target.value)}
        style={{ opacity: 0, position: "absolute", width: 0, height: 0, pointerEvents: "none" }}
      />
    </div>
  );
}

export default function App() {
  const [color, setColor] = useState(loadColor);
  const [currentPath, setCurrentPath] = useState(null);
  const [tree, setTree] = useState([]);
  const [search, setSearch] = useState("");
  const [showSearch, setShowSearch] = useState(false);
  const [searchResults, setSearchResults] = useState(null);
  const [searching, setSearching] = useState(false);

  const handleColorChange = (c) => {
    setColor(c);
    saveColor(c);
  };

  const loadDir = useCallback(async (dirPath) => {
    const items = await api?.readdir(dirPath) ?? [];
    setTree([...items].sort((a, b) =>
      a.type === b.type ? a.name.localeCompare(b.name) : a.type === "folder" ? -1 : 1
    ));
    setCurrentPath(dirPath);
    setSearch("");
    setSearchResults(null);
  }, []);

  useEffect(() => {
    (async () => {
      const start = await api?.startpath?.() ?? await api?.homedir() ?? "/home";
      loadDir(start);
    })();
  }, []);

  // Поиск с задержкой
  useEffect(() => {
    if (!search.trim()) { setSearchResults(null); return; }
    setSearching(true);
    const timer = setTimeout(async () => {
      const results = await searchAll(currentPath, search.trim());
      setSearchResults(results);
      setSearching(false);
    }, 300);
    return () => clearTimeout(timer);
  }, [search, currentPath]);

  const goUp = () => {
    if (!currentPath || currentPath === "/") return;
    const parent = currentPath.split("/").slice(0, -1).join("/") || "/";
    loadDir(parent);
  };

  const displayItems = searchResults ?? tree;

  return (
    <div style={{
      background: "#1e1e2e", height: "100vh",
      fontFamily: "'JetBrains Mono','Fira Mono',monospace",
      display: "flex", flexDirection: "column", overflow: "hidden"
    }}>
      {/* Заголовок */}
      <div style={{
        background: "#13131f", borderBottom: "1px solid #ffffff0f",
        padding: "6px 8px", display: "flex", alignItems: "center",
        justifyContent: "space-between", WebkitAppRegion: "drag", flexShrink: 0, gap: "6px"
      }}>
        {/* Левые кнопки */}
        <div style={{ display: "flex", alignItems: "center", gap: "1px", flexShrink: 0 }}>
          <TBtn title="Вверх" onClick={goUp}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <polyline points="18 15 12 9 6 15"/>
            </svg>
          </TBtn>
          <TBtn title="Обновить" onClick={() => currentPath && loadDir(currentPath)}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <polyline points="23 4 23 10 17 10"/>
              <polyline points="1 20 1 14 7 14"/>
              <path d="M3.51 9a9 9 0 0114.36-3.36L23 10M1 14l5.13 4.36A9 9 0 0020.49 15"/>
            </svg>
          </TBtn>
          <TBtn title="Поиск" onClick={() => setShowSearch(s => !s)}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="11" cy="11" r="7"/>
              <line x1="21" y1="21" x2="16.65" y2="16.65"/>
            </svg>
          </TBtn>
        </div>

        {/* Хлебные крошки — полный путь */}
        <div style={{ flex: 1, overflow: "hidden", minWidth: 0 }}>
          <Breadcrumbs path={currentPath} onNavigate={loadDir}/>
        </div>

        {/* Правые кнопки */}
        <div style={{ display: "flex", alignItems: "center", gap: "3px", flexShrink: 0 }}>
          <ColorButton color={color} onChange={handleColorChange}/>
          <div style={{ width: "1px", height: "12px", background: "#ffffff10", margin: "0 2px" }}/>
          <TBtn title="Свернуть" onClick={() => api?.minimize()}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <line x1="5" y1="12" x2="19" y2="12"/>
            </svg>
          </TBtn>
          <TBtn title="Развернуть" onClick={() => api?.maximize()}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <rect x="4" y="4" width="16" height="16" rx="1"/>
            </svg>
          </TBtn>
          <TBtn title="Закрыть" onClick={() => api?.close()} style={{ color: "#666" }}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <line x1="18" y1="6" x2="6" y2="18"/>
              <line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
          </TBtn>
        </div>
      </div>

      {/* Строка поиска */}
      {showSearch && (
        <div style={{ background: "#13131f", borderBottom: "1px solid #ffffff0f", padding: "5px 10px" }}>
          <input
            autoFocus
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="Поиск файлов и папок..."
            style={{
              width: "100%", background: "#ffffff08", border: "1px solid #ffffff12",
              borderRadius: "4px", color: "#ccc", fontSize: "12px",
              padding: "4px 8px", outline: "none", fontFamily: "inherit"
            }}
          />
        </div>
      )}

      {/* Дерево файлов */}
      <div style={{ overflowY: "auto", flex: 1, padding: "4px 0" }}>
        {searching && (
          <div style={{ color: "#555", fontSize: "12px", padding: "12px 16px" }}>Поиск...</div>
        )}
        {!searching && displayItems.length === 0 && (
          <div style={{ color: "#444", fontSize: "12px", padding: "16px", textAlign: "center" }}>
            {search ? "Ничего не найдено" : "Папка пуста"}
          </div>
        )}
        {!searching && displayItems.map((node, i) => (
          <TreeNode key={node.path || i} node={node} depth={0} color={color} onNavigate={loadDir}/>
        ))}
      </div>
    </div>
  );
}
