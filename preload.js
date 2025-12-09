const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
    getProfiles: () => ipcRenderer.invoke('get-profiles'),
    saveProfile: (name) => ipcRenderer.invoke('save-profile', name),
    saveProfileAll: (name, count) => ipcRenderer.invoke('save-profile-all', { name, count }),
    restoreProfile: (name) => ipcRenderer.invoke('restore-profile', name),
    restoreProfileAll: (name, count) => ipcRenderer.invoke('restore-profile-all', { name, count }),
    deleteProfile: (name) => ipcRenderer.invoke('delete-profile', name),
    getCurrentDisplay: () => ipcRenderer.invoke('get-current-display')
});
