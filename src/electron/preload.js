const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
  toMain: ipcRenderer.send,
  localStoreSet: (key, value) => ipcRenderer.send('local-store-set', key, value),
  clickedNew: () => ipcRenderer.send('clicked-new', null),
  clickedOpen: () => ipcRenderer.send('clicked-open', null),
  clickedImport: () => ipcRenderer.send('clicked-import', null),
  clickedDocument: (docPath) => ipcRenderer.send('clicked-document', docPath),
  clickedRemoveDocument: (docPath) => ipcRenderer.send('clicked-remove-document', docPath),
  clickedExport: (callback) => ipcRenderer.on('clicked-export', callback),
  clickedUndo: (callback) => ipcRenderer.on('clicked-undo', callback),
  clickedCut: (callback) => ipcRenderer.on('clicked-cut', callback),
  clickedCopy: (callback) => ipcRenderer.on('clicked-copy', callback),
  clickedPaste: (callback) => ipcRenderer.on('clicked-paste', callback),
  clickedPasteInto: (callback) => ipcRenderer.on('clicked-paste-into', callback),
  fileReceived: (callback) => ipcRenderer.on('file-received', callback),
  fileSaved: (callback) => ipcRenderer.on('file-saved', callback),
  exportFile: (data) => ipcRenderer.send('export-file', data),
  saveFile: (data) => ipcRenderer.send('save-file', data),
  commitData: (commitData) => ipcRenderer.send('commit-data', commitData),
  commitDataResult: (callback) => ipcRenderer.on('commit-data-result', callback),
  maybeCloseWindow: () => ipcRenderer.send('maybe-close-window'),
  closeWindow: () => ipcRenderer.send('close-window')
})
