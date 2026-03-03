const { app, BrowserWindow, ipcMain, shell, clipboard } = require("electron");
const path = require("path");
const fs   = require("fs");
const os   = require("os");
const { spawnSync } = require("child_process");

function getStartPath() {
  const args = process.argv.slice(2).filter(a => !a.startsWith("--"));
  if (args.length > 0 && fs.existsSync(args[0])) return args[0];
  return os.homedir();
}

// fs.watch per window
const watchers = new Map();
function watchDir(dirPath, wc) {
  if (watchers.has(dirPath)) return;
  let debounce = null;
  try {
    const w = fs.watch(dirPath, () => {
      clearTimeout(debounce);
      debounce = setTimeout(() => {
        if (!wc.isDestroyed()) wc.send("fs:changed", dirPath);
      }, 200);
    });
    w.on("error", () => {});
    watchers.set(dirPath, w);
  } catch {}
}

// IPC window drag (reliable on X11/XFCE)
const dragState = new WeakMap();
ipcMain.on("win:drag-start", (e, mx, my) => {
  const win = BrowserWindow.fromWebContents(e.sender); if (!win) return;
  const [wx, wy] = win.getPosition();
  dragState.set(win, { mx, my, wx, wy });
});
ipcMain.on("win:drag-move", (e, mx, my) => {
  const win = BrowserWindow.fromWebContents(e.sender); if (!win) return;
  const s = dragState.get(win); if (!s) return;
  win.setPosition(s.wx + (mx - s.mx), s.wy + (my - s.my));
});
ipcMain.on("win:drag-end", e => {
  const win = BrowserWindow.fromWebContents(e.sender);
  if (win) dragState.delete(win);
});

function createWindow(startPath) {
  const w = new BrowserWindow({
    width: 600, height: 740, minWidth: 380, minHeight: 440,
    frame: false, backgroundColor: "#1e1e2e", show: false,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true, nodeIntegration: false,
      additionalArguments: ["--start-path=" + (startPath || os.homedir())]
    }
  });
  w.loadFile(path.join(__dirname, "dist", "index.html"));
  // Show only after React signals it is painted
  ipcMain.once("renderer-ready", ev => {
    if (BrowserWindow.fromWebContents(ev.sender) === w) w.show();
  });
  setTimeout(() => { if (!w.isVisible()) w.show(); }, 3000);
  w.on("closed", () => { watchers.forEach((v,k) => { v.close(); watchers.delete(k); }); });
  return w;
}

ipcMain.handle("fs:readdir", (event, p) => {
  try {
    watchDir(p, event.sender);
    return fs.readdirSync(p, { withFileTypes: true }).map(e => ({
      name: e.name, type: e.isDirectory() ? "folder" : "file", path: path.join(p, e.name)
    }));
  } catch { return []; }
});
ipcMain.handle("fs:homedir",   ()     => os.homedir());
ipcMain.handle("fs:startpath", ()     => getStartPath());
ipcMain.handle("fs:open",      (_, p) => shell.openPath(p));

ipcMain.handle("fs:delete", (_, p) => {
  try {
    fs.statSync(p).isDirectory() ? fs.rmSync(p, { recursive: true, force: true }) : fs.unlinkSync(p);
    return { ok: true };
  } catch(e) { return { ok: false, error: e.message }; }
});

ipcMain.handle("fs:duplicate", (_, p) => {
  try {
    const dir = path.dirname(p), ext = path.extname(p), base = path.basename(p, ext);
    let dest = path.join(dir, base + " copy" + ext), n = 2;
    while (fs.existsSync(dest)) dest = path.join(dir, base + " copy " + (n++) + ext);
    fs.statSync(p).isDirectory() ? fs.cpSync(p, dest, { recursive: true }) : fs.copyFileSync(p, dest);
    return { ok: true };
  } catch(e) { return { ok: false, error: e.message }; }
});

ipcMain.handle("fs:move", (_, src, destDir) => {
  try {
    fs.renameSync(src, path.join(destDir, path.basename(src)));
    return { ok: true };
  } catch(e) { return { ok: false, error: e.message }; }
});

ipcMain.handle("fs:compress", (_, p) => {
  try {
    const dir = path.dirname(p), name = path.basename(p);
    let r = spawnSync("zip", ["-r", name + ".zip", name], { cwd: dir });
    if (r.status !== 0) r = spawnSync("tar", ["-czf", name + ".tar.gz", name], { cwd: dir });
    if (r.status !== 0) throw new Error("zip and tar both failed");
    return { ok: true };
  } catch(e) { return { ok: false, error: e.message }; }
});

ipcMain.handle("fs:copy-path", (_, p) => { clipboard.writeText(p); return { ok: true }; });
ipcMain.handle("win:new-window", (_, p) => { createWindow(p || os.homedir()); return { ok: true }; });

ipcMain.on("win:minimize", e => BrowserWindow.fromWebContents(e.sender)?.minimize());
ipcMain.on("win:maximize", e => {
  const w = BrowserWindow.fromWebContents(e.sender);
  w?.isMaximized() ? w.unmaximize() : w?.maximize();
});
ipcMain.on("win:close", e => BrowserWindow.fromWebContents(e.sender)?.close());

app.whenReady().then(() => createWindow(getStartPath()));
app.on("window-all-closed", () => app.quit());
