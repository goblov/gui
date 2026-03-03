const{app,BrowserWindow,ipcMain,shell,clipboard}=require("electron"),path=require("path"),fs=require("fs"),os=require("os"),{execSync}=require("child_process");
function getStartPath(){
  const args=process.argv.slice(2).filter(a=>!a.startsWith("--"));
  if(args.length>0&&fs.existsSync(args[0]))return args[0];
  return os.homedir();
}
function createWindow(startPath){
  const w=new BrowserWindow({width:560,height:720,minWidth:360,minHeight:400,frame:false,backgroundColor:"#1e1e2e",show:false,
    webPreferences:{preload:path.join(__dirname,"preload.js"),contextIsolation:true,nodeIntegration:false,
      additionalArguments:["--start-path="+(startPath||os.homedir())]}});
  w.loadFile(path.join(__dirname,"dist","index.html"));
  w.once("ready-to-show",()=>w.show());
  return w;
}
ipcMain.handle("fs:readdir",(_,p)=>{try{return fs.readdirSync(p,{withFileTypes:true}).map(e=>({name:e.name,type:e.isDirectory()?"folder":"file",path:path.join(p,e.name)}))}catch{return[]}});
ipcMain.handle("fs:homedir",()=>os.homedir());
ipcMain.handle("fs:startpath",()=>getStartPath());
ipcMain.handle("fs:open",(_,p)=>shell.openPath(p));
ipcMain.handle("fs:delete",(_,p)=>{try{fs.statSync(p).isDirectory()?fs.rmSync(p,{recursive:true,force:true}):fs.unlinkSync(p);return{ok:true}}catch(e){return{ok:false,error:e.message}}});
ipcMain.handle("fs:duplicate",(_,p)=>{
  try{
    const dir=path.dirname(p),base=path.basename(p,path.extname(p)),ext=path.extname(p);
    let dest=path.join(dir,base+" copy"+ext),n=2;
    while(fs.existsSync(dest))dest=path.join(dir,base+" copy "+n+++ext);
    fs.statSync(p).isDirectory()?fs.cpSync(p,dest,{recursive:true}):fs.copyFileSync(p,dest);
    return{ok:true,dest};
  }catch(e){return{ok:false,error:e.message}}
});
ipcMain.handle("fs:move",(_,src,destDir)=>{try{fs.renameSync(src,path.join(destDir,path.basename(src)));return{ok:true}}catch(e){return{ok:false,error:e.message}}});
ipcMain.handle("fs:compress",(_,p)=>{
  try{
    const dir=path.dirname(p),name=path.basename(p),zip=path.join(dir,name+".zip");
    try{execSync(`cd "${dir}" && zip -r "${zip}" "${name}" 2>/dev/null`)}
    catch{execSync(`cd "${dir}" && tar -czf "${name}.tar.gz" "${name}" 2>/dev/null`)}
    return{ok:true};
  }catch(e){return{ok:false,error:e.message}}
});
ipcMain.handle("fs:copy-path",(_,p)=>{clipboard.writeText(p);return{ok:true}});
ipcMain.handle("win:new-window",(_,p)=>{createWindow(p||os.homedir());return{ok:true}});
ipcMain.on("win:minimize",e=>BrowserWindow.fromWebContents(e.sender)?.minimize());
ipcMain.on("win:maximize",e=>{const w=BrowserWindow.fromWebContents(e.sender);w?.isMaximized()?w.unmaximize():w?.maximize()});
ipcMain.on("win:close",e=>BrowserWindow.fromWebContents(e.sender)?.close());
app.whenReady().then(()=>createWindow(getStartPath()));
app.on("window-all-closed",()=>app.quit());
