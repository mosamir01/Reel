'use strict';

const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const path  = require('path');
const { spawn } = require('child_process');
const fs    = require('fs');
const os    = require('os');

// ── Settings ──────────────────────────────────────────────────────────────────

let settings = {};
const settingsFile = () => path.join(app.getPath('userData'), 'settings.json');

function loadSettings() {
  try { settings = JSON.parse(fs.readFileSync(settingsFile(), 'utf8')); } catch { settings = {}; }
}
function saveSettings() {
  try { fs.writeFileSync(settingsFile(), JSON.stringify(settings, null, 2), 'utf8'); } catch {}
}

// ── State ─────────────────────────────────────────────────────────────────────

let items        = [];   // download items (with _process / _errorLines internals)
let outputFolder = null;
let mainWindow   = null;
const MAX_CONCURRENT = 3;

function uid() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
}

// Strip internal fields before sending to renderer
function safeItems() {
  return items.map(({ _process, _errorLines, ...rest }) => rest);
}
function pushState() {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  mainWindow.webContents.send('state:update', { items: safeItems(), outputFolder });
}

// ── Binary lookup ─────────────────────────────────────────────────────────────

function findBin(name) {
  const isWin  = process.platform === 'win32';
  const exe    = isWin ? `${name}.exe` : name;
  const sep    = isWin ? ';' : ':';

  // bundled (inside the asar / resources)
  const bundled = path.join(
    process.resourcesPath ?? path.join(app.getAppPath(), '..'),
    'bin', exe
  );
  if (fs.existsSync(bundled)) return bundled;

  // PATH
  for (const dir of (process.env.PATH || '').split(sep)) {
    const full = path.join(dir.trim(), exe);
    if (fs.existsSync(full)) return full;
  }

  // Windows extra locations
  if (isWin) {
    const home = os.homedir();
    for (const p of [
      path.join(home, 'AppData', 'Local', 'Programs', 'yt-dlp', exe),
      path.join(home, 'scoop', 'shims', exe),
      path.join(home, 'scoop', 'apps', name, 'current', exe),
      `C:\\yt-dlp\\${exe}`,
    ]) { if (fs.existsSync(p)) return p; }
  }

  return null;
}

// ── yt-dlp format args ────────────────────────────────────────────────────────

function formatArgs(format) {
  switch (format) {
    case 'best':
      return ['-f', 'best/best'];
    case 'mp4':
      return ['-f', 'best[ext=mp4]/best[vcodec!=none][acodec!=none]/best'];
    case 'mp3':
      return ['-f', 'bestaudio[ext=m4a]/bestaudio[ext=mp3]/bestaudio'];
    case 'wav':
      return ['-f', 'bestaudio[ext=m4a]/bestaudio'];
    default: return [];
  }
}

// ── Output parser ─────────────────────────────────────────────────────────────

function parseLine(line, item) {
  const t = line.trim();
  if (!t) return;

  if (t.includes('[download] Destination:')) {
    const f = t.split('Destination: ').pop().trim();
    if (f) { item.title = path.basename(f, path.extname(f)); item.filePath = f; }
  }

  if (t.includes('[Merger] Merging formats into')) {
    const m = t.match(/"([^"]+)"/);
    if (m) item.filePath = m[1].trim();
    item.status = 'converting'; item.progress = 0.99;
  }

  if (t.startsWith('[download]') && t.includes('%') && !t.includes('has already been downloaded')) {
    const parts = t.split(/\s+/).filter(Boolean);
    for (let i = 0; i < parts.length; i++) {
      if (parts[i].endsWith('%')) {
        const v = parseFloat(parts[i]);
        if (!isNaN(v)) item.progress = Math.min(v / 100, 1);
      }
      if (parts[i].endsWith('/s')) item.speed = parts[i];
      if (i > 0 && parts[i - 1] === 'ETA') item.eta = parts[i] === 'Unknown' ? '' : parts[i];
    }
    item.status = 'downloading';
  }

  if (t.includes('has already been downloaded')) { item.status = 'done'; item.progress = 1; }

  if (t.startsWith('ERROR:')) {
    item._errorLines.push(t.replace(/^ERROR:\s*/, ''));
  }
}

// ── Download engine ───────────────────────────────────────────────────────────

function activeCount() {
  return items.filter(i => ['fetching', 'downloading', 'converting'].includes(i.status)).length;
}

function processQueue() {
  const slots  = MAX_CONCURRENT - activeCount();
  const queued = items.filter(i => i.status === 'queued');
  for (const item of queued.slice(0, slots)) startDownload(item);
}

async function startDownload(item) {
  if (!outputFolder) {
    item.status = 'failed';
    item.errorMessage = 'No output folder selected.';
    pushState(); return;
  }

  const ytdlp = findBin('yt-dlp');
  if (!ytdlp) {
    item.status    = 'failed';
    item.errorMessage = process.platform === 'win32'
      ? 'yt-dlp not found.\nInstall: winget install yt-dlp.yt-dlp   (or: scoop install yt-dlp)'
      : 'yt-dlp not found.\nInstall: brew install yt-dlp';
    pushState(); return;
  }

  item.status = 'fetching';
  pushState();

  const outTpl = path.join(outputFolder, '%(title)s.%(ext)s');
  const args   = [
    '--newline', '--progress', '--no-playlist',
    '-o', outTpl,
    ...formatArgs(item.format),
    item.url,
  ];

  const proc = spawn(ytdlp, args, { windowsHide: true });
  item._process = proc;

  let buf = '';
  const onData = (data) => {
    buf += data.toString('utf8');
    const lines = buf.split('\n');
    buf = lines.pop();
    for (const l of lines) parseLine(l, item);
    pushState();
  };
  proc.stdout.on('data', onData);
  proc.stderr.on('data', onData);

  let exitCode = 0;
  await new Promise(resolve => proc.on('close', (code) => { exitCode = code ?? 0; resolve(); }));

  item._process = null;

  if (!['done', 'failed'].includes(item.status)) {
    if (exitCode === 0) {
      item.status   = 'done';
      item.progress = 1.0;
    } else {
      item.status       = 'failed';
      item.errorMessage = item._errorLines.at(-1)
        ?? 'Download failed. Check that the URL is valid and yt-dlp is up to date.';
    }
  }

  pushState();
  processQueue();
}

// ── IPC ───────────────────────────────────────────────────────────────────────

ipcMain.handle('state:get', () => ({ items: safeItems(), outputFolder }));

ipcMain.handle('download:add', (_, { url, format }) => {
  if (!outputFolder) { mainWindow.webContents.send('show:folderSetup'); return; }
  const clean = url.trim();
  if (!clean) return;
  let hostname = clean;
  try { hostname = new URL(clean).hostname; } catch {}
  const item = {
    id: uid(), url: clean, format,
    title: hostname, status: 'queued',
    progress: 0, speed: '', eta: '', filePath: null, errorMessage: null,
    _process: null, _errorLines: [],
  };
  items.unshift(item);
  pushState();
  processQueue();
});

ipcMain.handle('download:cancel', (_, id) => {
  const item = items.find(i => i.id === id);
  if (item?._process) { item._process.kill(); item._process = null; }
  items = items.filter(i => i.id !== id);
  pushState(); processQueue();
});

ipcMain.handle('download:remove', (_, id) => {
  items = items.filter(i => i.id !== id);
  pushState();
});

ipcMain.handle('download:retry', (_, id) => {
  const old = items.find(i => i.id === id);
  if (!old) return;
  let hostname = old.url;
  try { hostname = new URL(old.url).hostname; } catch {}
  const item = {
    id: uid(), url: old.url, format: old.format,
    title: hostname, status: 'queued',
    progress: 0, speed: '', eta: '', filePath: null, errorMessage: null,
    _process: null, _errorLines: [],
  };
  items = items.filter(i => i.id !== id);
  items.unshift(item);
  pushState(); processQueue();
});

ipcMain.handle('download:openFile', (_, id) => {
  const item = items.find(i => i.id === id);
  if (item?.filePath && fs.existsSync(item.filePath)) shell.openPath(item.filePath);
  else if (outputFolder) shell.openPath(outputFolder);
});

ipcMain.handle('download:clearCompleted', () => {
  items = items.filter(i => !['done', 'failed'].includes(i.status));
  pushState();
});

ipcMain.handle('folder:pick', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openDirectory', 'createDirectory'],
    title: 'Choose Download Folder',
    buttonLabel: 'Choose',
  });
  if (!result.canceled && result.filePaths[0]) {
    outputFolder         = result.filePaths[0];
    settings.outputFolder = outputFolder;
    saveSettings();
    pushState();
    return outputFolder;
  }
  return null;
});

ipcMain.handle('folder:openInExplorer', () => {
  if (outputFolder) shell.openPath(outputFolder);
});

// ── Window ────────────────────────────────────────────────────────────────────

function createWindow() {
  const iconFile = process.platform === 'win32'  ? 'icon.ico'
                 : process.platform === 'darwin' ? 'icon.icns'
                 : 'icon_512.png';

  mainWindow = new BrowserWindow({
    width: 900, height: 620,
    minWidth: 720, minHeight: 480,
    backgroundColor: '#0A0A0A',
    icon: path.join(__dirname, 'assets', iconFile),
    show: false,
    titleBarStyle: 'hidden',
    titleBarOverlay: {
      color:       '#0B0B0B',
      symbolColor: '#888888',
      height:      38,
    },
    webPreferences: {
      preload:          path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration:  false,
    },
  });

  mainWindow.loadFile(path.join(__dirname, 'src', 'index.html'));

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
    if (!outputFolder) mainWindow.webContents.send('show:folderSetup');
  });
}

app.whenReady().then(() => {
  loadSettings();
  outputFolder = settings.outputFolder ?? null;
  if (outputFolder && !fs.existsSync(outputFolder)) outputFolder = null;

  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
