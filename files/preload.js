const{contextBridge,ipcRenderer}=require("electron");
contextBridge.exposeInMainWorld("electronAPI",{
  readdir:   p=>ipcRenderer.invoke("fs:readdir",p),
  homedir:   ()=>ipcRenderer.invoke("fs:homedir"),
  startpath: ()=>ipcRenderer.invoke("fs:startpath"),
  openFile:  p=>ipcRenderer.invoke("fs:open",p),
  deleteItem:p=>ipcRenderer.invoke("fs:delete",p),
  duplicate: p=>ipcRenderer.invoke("fs:duplicate",p),
  move:    (s,d)=>ipcRenderer.invoke("fs:move",s,d),
  compress:  p=>ipcRenderer.invoke("fs:compress",p),
  copyPath:  p=>ipcRenderer.invoke("fs:copy-path",p),
  newWindow: p=>ipcRenderer.invoke("win:new-window",p),
  minimize:  ()=>ipcRenderer.send("win:minimize"),
  maximize:  ()=>ipcRenderer.send("win:maximize"),
  close:     ()=>ipcRenderer.send("win:close")
});
