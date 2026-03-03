import { useState, useEffect, useCallback, useRef } from "react";

const api = window.electronAPI;
const COLOR_KEY   = "filetree_color";
const SIDEBAR_KEY = "filetree_sidebar";
const DEFAULT_COLOR = "#b39ddb";
const loadColor = () => { try { return localStorage.getItem(COLOR_KEY)||DEFAULT_COLOR; } catch { return DEFAULT_COLOR; } };
const saveColor = c  => { try { localStorage.setItem(COLOR_KEY, c); } catch {} };

/* ── tiny helpers ── */
const sortItems = items =>
  [...items].sort((a,b)=>a.type===b.type?a.name.localeCompare(b.name):a.type==="folder"?-1:1);

/* ── Icons ── */
function FolderIcon({color,open}){return(
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" style={{flexShrink:0}}>
    <path d="M2 6C2 4.9 2.9 4 4 4H9.17C9.7 4 10.21 4.21 10.59 4.59L12 6H20C21.1 6 22 6.9 22 8V18C22 19.1 21.1 20 20 20H4C2.9 20 2 19.1 2 18V6Z"
      fill={open?color+"33":color+"22"} stroke={color} strokeWidth="1.5" strokeLinejoin="round"/>
    {open&&<path d="M2 10H22" stroke={color} strokeWidth="1.2" strokeOpacity="0.5"/>}
  </svg>);}
function FileIcon(){return(
  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" style={{flexShrink:0}}>
    <path d="M13 2H6C4.9 2 4 2.9 4 4V20C4 21.1 4.9 22 6 22H18C19.1 22 20 21.1 20 20V9L13 2Z" fill="#ffffff0d" stroke="#555" strokeWidth="1.5" strokeLinejoin="round"/>
    <path d="M13 2V9H20" stroke="#555" strokeWidth="1.5" strokeLinecap="round"/>
  </svg>);}
function Chevron({open}){return(
  <svg width="8" height="8" viewBox="0 0 10 10" fill="none"
    style={{flexShrink:0,transition:"transform 0.12s",transform:open?"rotate(90deg)":"rotate(0deg)"}}>
    <path d="M3 2L7 5L3 8" stroke="#444" strokeWidth="1.5" strokeLinecap="round"/>
  </svg>);}
function SidebarIcon({type}){
  const p={width:13,height:13,viewBox:"0 0 24 24",fill:"none",stroke:"currentColor",strokeWidth:"1.8",strokeLinecap:"round",strokeLinejoin:"round",style:{flexShrink:0}};
  if(type==="home")      return <svg {...p}><path d="M3 9.5L12 3l9 6.5V20a1 1 0 01-1 1H4a1 1 0 01-1-1V9.5z"/><path d="M9 21V12h6v9"/></svg>;
  if(type==="desktop")   return <svg {...p}><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/></svg>;
  if(type==="documents") return <svg {...p}><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="8" y1="13" x2="16" y2="13"/><line x1="8" y1="17" x2="16" y2="17"/></svg>;
  if(type==="downloads") return <svg {...p}><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>;
  if(type==="music")     return <svg {...p}><path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/></svg>;
  if(type==="pictures")  return <svg {...p}><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>;
  if(type==="videos")    return <svg {...p}><polygon points="23 7 16 12 23 17 23 7"/><rect x="1" y="5" width="15" height="14" rx="2"/></svg>;
  return <svg {...p}><path d="M22 19a2 2 0 01-2 2H4a2 2 0 01-2-2V5a2 2 0 012-2h5l2 3h9a2 2 0 012 2z"/></svg>;
}
function TBtn({title,onClick,children}){return(
  <button title={title} onClick={onClick}
    style={{background:"transparent",border:"none",cursor:"pointer",padding:"4px",display:"flex",alignItems:"center",color:"#555",borderRadius:"3px",transition:"color 0.1s",userSelect:"none"}}
    onMouseEnter={e=>e.currentTarget.style.color="#bbb"}
    onMouseLeave={e=>e.currentTarget.style.color="#555"}>{children}</button>);}

/* ── Context Menu ── */
function ContextMenu({x,y,items,onClose}){
  const ref=useRef(null);
  useEffect(()=>{
    const close=e=>{if(!ref.current?.contains(e.target))onClose();};
    const t=setTimeout(()=>{window.addEventListener("mousedown",close);window.addEventListener("contextmenu",close);},0);
    return()=>{clearTimeout(t);window.removeEventListener("mousedown",close);window.removeEventListener("contextmenu",close);};
  },[onClose]);
  const left=Math.min(x,window.innerWidth-215), top=Math.min(y,window.innerHeight-items.length*32-10);
  return(
    <div ref={ref} onContextMenu={e=>e.preventDefault()}
      style={{position:"fixed",zIndex:9999,left,top,background:"#16161f",border:"1px solid #ffffff18",borderRadius:"8px",padding:"4px 0",minWidth:"200px",boxShadow:"0 12px 40px #00000099",fontFamily:"inherit"}}>
      {items.map((item,i)=>item.sep
        ? <div key={i} style={{height:"1px",background:"#ffffff0f",margin:"3px 0"}}/>
        : <div key={i} onClick={()=>{item.fn();onClose();}}
            style={{padding:"6px 14px",fontSize:"12px",cursor:"pointer",userSelect:"none",color:item.red?"#ff6b6b":"#ccc"}}
            onMouseEnter={e=>e.currentTarget.style.background="#ffffff0d"}
            onMouseLeave={e=>e.currentTarget.style.background="transparent"}>{item.label}</div>
      )}
    </div>);
}

/* ── Sidebar ── */
function Sidebar({currentPath,onNavigate,home,dragPath}){
  const [ctx,setCtx]=useState(null);
  const [dropIdx,setDropIdx]=useState(null);
  const [favs,setFavs]=useState(()=>{
    try{const s=localStorage.getItem(SIDEBAR_KEY);return s?JSON.parse(s):null;}catch{return null;}
  });
  const defaults=home?[
    {name:"Домашняя",     type:"home",      path:home},
    {name:"Рабочий стол", type:"desktop",   path:home+"/Desktop"},
    {name:"Документы",    type:"documents", path:home+"/Documents"},
    {name:"Загрузки",     type:"downloads", path:home+"/Downloads"},
    {name:"Музыка",       type:"music",     path:home+"/Music"},
    {name:"Изображения",  type:"pictures",  path:home+"/Pictures"},
    {name:"Видео",        type:"videos",    path:home+"/Videos"},
  ]:[];
  const list=favs||defaults;
  const save=f=>{setFavs(f);localStorage.setItem(SIDEBAR_KEY,JSON.stringify(f));};
  const openCtx=(e,item)=>{
    e.preventDefault();e.stopPropagation();
    setCtx({x:e.clientX,y:e.clientY,items:[
      {label:"Открыть в новой вкладке",   fn:()=>api?.newWindow(item.path)},
      {label:"Показать содержащую папку", fn:()=>onNavigate(item.path.split("/").slice(0,-1).join("/")||"/")},
      {sep:true},
      {label:"Удалить из избранного",     fn:()=>save(list.filter(f=>f.path!==item.path)),red:true},
    ]});
  };
  // Drop from tree into sidebar
  const onDragOver=e=>{
    if(!dragPath)return;
    e.preventDefault();setDropIdx(-1);
  };
  const onDrop=e=>{
    e.preventDefault();setDropIdx(null);
    const p=e.dataTransfer.getData("text/plain")||dragPath;
    if(!p)return;
    if(list.some(f=>f.path===p))return;
    const name=p.split("/").pop()||p;
    save([...list,{name,type:"folder",path:p}]);
  };
  return(
    <div onDragOver={onDragOver} onDragLeave={()=>setDropIdx(null)} onDrop={onDrop}
      style={{width:"150px",flexShrink:0,background:"#0f0f1a",borderRight:"1px solid #ffffff08",display:"flex",flexDirection:"column",overflowY:"auto",overflowX:"hidden",position:"relative"}}>
      {dropIdx!=null&&<div style={{position:"absolute",bottom:0,left:0,right:0,height:"3px",background:"#b39ddb55",borderRadius:"2px"}}/>}
      {list.map((item,i)=>{
        const active=currentPath===item.path;
        return(
          <div key={i} onClick={()=>onNavigate(item.path)} onContextMenu={e=>openCtx(e,item)}
            style={{display:"flex",alignItems:"center",gap:"7px",padding:"5px 8px 5px 10px",cursor:"pointer",borderRadius:"5px",margin:"1px 4px",background:active?"#ffffff0f":"transparent",color:active?"#bbb":"#555",fontSize:"12px",userSelect:"none",transition:"all 0.1s"}}
            onMouseEnter={e=>{if(!active)e.currentTarget.style.background="#ffffff08";}}
            onMouseLeave={e=>{if(!active)e.currentTarget.style.background="transparent";}}>
            <SidebarIcon type={item.type}/>
            <span style={{overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{item.name}</span>
          </div>);
      })}
      <div style={{flex:1,minHeight:"20px",display:"flex",alignItems:"center",justifyContent:"center",padding:"8px 0",color:"#333",fontSize:"10px"}}>
        {dropIdx!=null?"Отпустите для добавления":""}
      </div>
      {ctx&&<ContextMenu x={ctx.x} y={ctx.y} items={ctx.items} onClose={()=>setCtx(null)}/>}
    </div>);
}

/* ── Breadcrumbs ── */
function Breadcrumbs({path,onNavigate}){
  if(!path)return null;
  const parts=path.split("/").filter(Boolean);
  const segs=[{label:"/",fp:"/"}, ...parts.map((p,i)=>({label:p,fp:"/"+parts.slice(0,i+1).join("/")}))];
  return(
    <div style={{display:"flex",alignItems:"center",flexWrap:"nowrap",overflow:"hidden",gap:"1px",userSelect:"none"}}>
      {segs.map((s,i)=>(
        <span key={i} style={{display:"flex",alignItems:"center",flexShrink:i<segs.length-2?1:0}}>
          {i>0&&<span style={{color:"#2a2a3a",margin:"0 1px",fontSize:"10px"}}>/</span>}
          <span onClick={()=>onNavigate(s.fp)}
            style={{color:i===segs.length-1?"#999":"#444",fontSize:"11px",cursor:"pointer",padding:"1px 3px",borderRadius:"3px",whiteSpace:"nowrap",overflow:"hidden",textOverflow:"ellipsis",maxWidth:i<segs.length-2?"55px":"none",transition:"color 0.1s"}}
            onMouseEnter={e=>e.currentTarget.style.color="#fff"}
            onMouseLeave={e=>e.currentTarget.style.color=i===segs.length-1?"#999":"#444"}>{s.label}</span>
        </span>))}
    </div>);}

/* ── Color Button ── */
function ColorButton({color,onChange}){
  const ref=useRef(null);
  return(
    <div title="Цвет папок" onClick={()=>ref.current?.click()} style={{width:"13px",height:"13px",borderRadius:"50%",background:color,cursor:"pointer",flexShrink:0,boxShadow:"0 0 0 1.5px #ffffff20",position:"relative",userSelect:"none"}}>
      <input ref={ref} type="color" value={color} onChange={e=>onChange(e.target.value)}
        style={{opacity:0,position:"absolute",width:0,height:0,pointerEvents:"none"}}/>
    </div>);}

/* ── BFS Search ── */
async function searchAll(rootPath,query){
  const results=[],lq=query.toLowerCase(),queue=[rootPath],visited=new Set();
  while(queue.length>0){
    const batch=queue.splice(0,20);
    await Promise.all(batch.map(async dir=>{
      if(visited.has(dir))return; visited.add(dir);
      const items=await api?.readdir(dir)??[];
      for(const item of items){
        if(item.name.toLowerCase().includes(lq))results.push(item);
        if(item.type==="folder")queue.push(item.path);
      }
    }));
  }
  return results;
}

/* ── Tree Node ── */
function TreeNode({node,depth,color,onNavigate,onRefresh,onDragChange}){
  const [open,setOpen]         =useState(false);
  const [children,setChildren] =useState(null);
  const [dropOver,setDropOver] =useState(false);
  const [ctx,setCtx]           =useState(null);
  const isFolder=node.type==="folder";

  const expand=useCallback(async()=>{
    const items=await api?.readdir(node.path)??[];
    setChildren(sortItems(items));
  },[node.path]);

  const handleClick=useCallback(async()=>{
    if(!isFolder){api?.openFile(node.path);return;}
    if(!open&&children===null)await expand();
    setOpen(o=>!o);
  },[isFolder,open,children,expand]);

  // Drag source
  const onDragStart=e=>{
    e.stopPropagation();
    e.dataTransfer.setData("text/plain",node.path);
    e.dataTransfer.effectAllowed="move";
    onDragChange?.(node.path);
  };
  const onDragEnd=e=>{
    e.stopPropagation();
    onDragChange?.(null);
  };
  // Drop target (folders only)
  const onDragOver=e=>{
    if(!isFolder)return;
    e.preventDefault();e.stopPropagation();
    e.dataTransfer.dropEffect="move";
    setDropOver(true);
  };
  const onDragLeave=e=>{e.stopPropagation();setDropOver(false);};
  const onDrop=async e=>{
    e.preventDefault();e.stopPropagation();setDropOver(false);
    const src=e.dataTransfer.getData("text/plain");
    if(!src||src===node.path)return;
    const r=await api?.move(src,node.path);
    if(r?.ok){onRefresh?.();if(open)await expand();}
    else alert("Ошибка перемещения: "+(r?.error||"unknown"));
  };

  const ctxItems=[
    {label:"Открыть в новой вкладке",fn:()=>api?.newWindow(isFolder?node.path:undefined)},
    {sep:true},
    {label:"Удалить",red:true,fn:async()=>{
      if(confirm("Удалить «"+node.name+"» навсегда?")){
        const r=await api?.deleteItem(node.path);
        if(r?.ok)onRefresh?.();else alert("Ошибка: "+(r?.error||"unknown"));
      }
    }},
    {sep:true},
    {label:"Сжать",fn:async()=>{
      const r=await api?.compress(node.path);
      if(r?.ok)onRefresh?.();else alert("Ошибка сжатия: "+(r?.error||"zip/tar не установлен"));
    }},
    {label:"Дублировать",fn:async()=>{
      const r=await api?.duplicate(node.path);
      if(r?.ok)onRefresh?.();else alert("Ошибка: "+(r?.error||"unknown"));
    }},
    {label:"Скопировать путь",fn:()=>api?.copyPath(node.path)},
  ];

  return(
    <div>
      <div draggable
        onDragStart={onDragStart} onDragEnd={onDragEnd}
        onDragOver={onDragOver} onDragLeave={onDragLeave} onDrop={onDrop}
        onClick={handleClick}
        onDoubleClick={()=>isFolder&&onNavigate?.(node.path)}
        onContextMenu={e=>{e.preventDefault();e.stopPropagation();setCtx({x:e.clientX,y:e.clientY});}}
        style={{display:"flex",alignItems:"center",gap:"5px",
          padding:"3px 8px 3px "+(8+depth*14)+"px",
          cursor:"pointer",borderRadius:"4px",userSelect:"none",
          fontSize:"12.5px",color:"#ccc",transition:"background 0.1s",
          background:dropOver?"#b39ddb18":"transparent",
          outline:dropOver?"1px solid #b39ddb66":"none"}}
        onMouseEnter={e=>{if(!dropOver)e.currentTarget.style.background="#ffffff0d";}}
        onMouseLeave={e=>{if(!dropOver)e.currentTarget.style.background="transparent";}}>
        {isFolder?<><Chevron open={open}/><FolderIcon color={color} open={open}/></>:<><span style={{width:8}}/><FileIcon/></>}
        <span style={{marginLeft:2,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap",flex:1}}>{node.name}</span>
      </div>
      {isFolder&&open&&children?.map((child,i)=>(
        <TreeNode key={child.path||i} node={child} depth={depth+1}
          color={color} onNavigate={onNavigate} onRefresh={onRefresh} onDragChange={onDragChange}/>
      ))}
      {ctx&&<ContextMenu x={ctx.x} y={ctx.y} items={ctxItems} onClose={()=>setCtx(null)}/>}
    </div>);}

/* ── App ── */
export default function App(){
  const [color,setColor]         =useState(loadColor);
  const [currentPath,setPath]    =useState(null);
  const [home,setHome]           =useState(null);
  const [tree,setTree]           =useState([]);
  const [search,setSearch]       =useState("");
  const [showSearch,setShowSrch] =useState(false);
  const [searchRes,setSearchRes] =useState(null);
  const [searching,setSearching] =useState(false);
  const [dragPath,setDragPath]   =useState(null);

  const loadDir=useCallback(async dir=>{
    const items=await api?.readdir(dir)??[];
    setTree(sortItems(items));setPath(dir);setSearch("");setSearchRes(null);
  },[]);

  const refresh=useCallback(()=>{if(currentPath)loadDir(currentPath);},[currentPath,loadDir]);

  // Init
  useEffect(()=>{
    (async()=>{
      const h=await api?.homedir()??"/home"; setHome(h);
      const start=await api?.startpath?.()??h;
      await loadDir(start);
      // Signal main: React is painted, show window now (no white flash)
      api?.signalReady?.();
    })();
  },[]);

  // Auto-refresh on fs changes
  useEffect(()=>{
    api?.onDirChanged?.(dir=>{
      if(dir===currentPath)loadDir(currentPath);
    });
  },[currentPath]);

  // BFS search
  useEffect(()=>{
    if(!search.trim()){setSearchRes(null);return;}
    setSearching(true);
    const t=setTimeout(async()=>{const r=await searchAll(currentPath,search.trim());setSearchRes(r);setSearching(false);},300);
    return()=>clearTimeout(t);
  },[search,currentPath]);

  const goUp=()=>{if(!currentPath||currentPath==="/")return;loadDir(currentPath.split("/").slice(0,-1).join("/")||"/");};
  const items=searchRes??tree;

  // IPC-based titlebar drag (works on X11/XFCE, no WebkitAppRegion tricks needed)
  const titlebarRef=useRef(null);
  const onTitleMouseDown=useCallback(e=>{
    // Only drag on the titlebar itself, not on buttons/breadcrumbs
    if(e.target.closest("button")||e.target.closest("span")||e.target.closest("input")||e.target.closest("div[data-nodrag]"))return;
    if(e.button!==0)return;
    e.preventDefault();
    api?.winDragStart(e.screenX,e.screenY);
    const onMove=e=>{api?.winDragMove(e.screenX,e.screenY);};
    const onUp=()=>{api?.winDragEnd();window.removeEventListener("mousemove",onMove);window.removeEventListener("mouseup",onUp);};
    window.addEventListener("mousemove",onMove);
    window.addEventListener("mouseup",onUp);
  },[]);

  return(
    <div style={{background:"#1e1e2e",height:"100vh",fontFamily:"'JetBrains Mono','Fira Mono',monospace",display:"flex",flexDirection:"column",overflow:"hidden"}}>

      {/* Titlebar — draggable via IPC mouse tracking */}
      <div ref={titlebarRef} onMouseDown={onTitleMouseDown}
        style={{background:"#0f0f1a",borderBottom:"1px solid #ffffff08",padding:"5px 8px",display:"flex",alignItems:"center",justifyContent:"space-between",flexShrink:0,gap:"6px",cursor:"default",userSelect:"none"}}>
        <div data-nodrag="1" style={{display:"flex",alignItems:"center",gap:"1px",flexShrink:0}}>
          <TBtn title="Вверх" onClick={goUp}><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><polyline points="18 15 12 9 6 15"/></svg></TBtn>
          <TBtn title="Поиск" onClick={()=>setShowSrch(s=>!s)}><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg></TBtn>
        </div>
        <div data-nodrag="1" style={{flex:1,overflow:"hidden",minWidth:0}}>
          <Breadcrumbs path={currentPath} onNavigate={loadDir}/>
        </div>
        <div data-nodrag="1" style={{display:"flex",alignItems:"center",gap:"3px",flexShrink:0}}>
          <ColorButton color={color} onChange={c=>{setColor(c);saveColor(c);}}/>
          <div style={{width:"1px",height:"11px",background:"#ffffff0d",margin:"0 2px"}}/>
          <TBtn title="Свернуть"   onClick={()=>api?.minimize()}><svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><line x1="5" y1="12" x2="19" y2="12"/></svg></TBtn>
          <TBtn title="Развернуть" onClick={()=>api?.maximize()}><svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="4" y="4" width="16" height="16" rx="1"/></svg></TBtn>
          <TBtn title="Закрыть"    onClick={()=>api?.close()}><svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></TBtn>
        </div>
      </div>

      {showSearch&&(
        <div style={{background:"#0f0f1a",borderBottom:"1px solid #ffffff08",padding:"4px 10px"}}>
          <input autoFocus value={search} onChange={e=>setSearch(e.target.value)} placeholder="Поиск файлов и папок..."
            style={{width:"100%",background:"#ffffff06",border:"1px solid #ffffff10",borderRadius:"4px",color:"#ccc",fontSize:"12px",padding:"4px 8px",outline:"none",fontFamily:"inherit"}}/>
        </div>
      )}

      <div style={{display:"flex",flex:1,overflow:"hidden"}}>
        <Sidebar currentPath={currentPath} onNavigate={loadDir} home={home} dragPath={dragPath}/>
        <div style={{overflowY:"auto",flex:1,padding:"4px 0"}}>
          {searching&&<div style={{color:"#444",fontSize:"12px",padding:"12px 16px"}}>Поиск...</div>}
          {!searching&&items.length===0&&<div style={{color:"#333",fontSize:"12px",padding:"16px",textAlign:"center"}}>{search?"Ничего не найдено":"Папка пуста"}</div>}
          {!searching&&items.map((node,i)=>(
            <TreeNode key={node.path||i} node={node} depth={0}
              color={color} onNavigate={loadDir} onRefresh={refresh} onDragChange={setDragPath}/>
          ))}
        </div>
      </div>
    </div>);}
