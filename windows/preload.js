'use strict';
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('reel', {
  getState:        ()           => ipcRenderer.invoke('state:get'),
  addDownload:     (url, fmt)   => ipcRenderer.invoke('download:add', { url, format: fmt }),
  cancelDownload:  (id)         => ipcRenderer.invoke('download:cancel', id),
  removeDownload:  (id)         => ipcRenderer.invoke('download:remove', id),
  retryDownload:   (id)         => ipcRenderer.invoke('download:retry', id),
  openFile:        (id)         => ipcRenderer.invoke('download:openFile', id),
  clearCompleted:  ()           => ipcRenderer.invoke('download:clearCompleted'),
  pickFolder:      ()           => ipcRenderer.invoke('folder:pick'),
  openFolder:      ()           => ipcRenderer.invoke('folder:openInExplorer'),
  onStateUpdate:      (cb) => ipcRenderer.on('state:update',       (_, d) => cb(d)),
  onShowFolderSetup:  (cb) => ipcRenderer.on('show:folderSetup',   ()     => cb()),
});
