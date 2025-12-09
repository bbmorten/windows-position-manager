const { app, BrowserWindow, ipcMain, dialog, Tray, Menu, nativeImage, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const { execFile } = require('child_process');
const os = require('os');

const SCRIPT_PATH = path.join(__dirname, 'scripts', 'window-manager.sh');
const CONFIG_DIR = path.join(os.homedir(), '.config', 'window-manager', 'profiles');
const ICON_PATH = path.join(__dirname, 'assets', 'robot-logo.png');

let mainWindow = null;
let tray = null;

function createWindow() {
    mainWindow = new BrowserWindow({
        width: 1000,
        height: 700,
        titleBarStyle: 'hiddenInset',
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            nodeIntegration: false,
            contextIsolation: true
        },
        vibrancy: 'under-window', // macOS vibrancy
        visualEffectState: 'active',
        icon: ICON_PATH
    });

    mainWindow.loadFile('index.html');

    mainWindow.on('close', (event) => {
        if (!app.isQuitting) {
            event.preventDefault();
            mainWindow.hide();
        }
        return false;
    });
}

function getProfilesData() {
    try {
        if (!fs.existsSync(CONFIG_DIR)) {
            return [];
        }
        const files = fs.readdirSync(CONFIG_DIR).filter(file => file.endsWith('.json'));
        // Group profiles if they follow the pattern Name_SpaceN
        const profilesMap = new Map();

        files.forEach(file => {
            const content = fs.readFileSync(path.join(CONFIG_DIR, file), 'utf-8');
            try {
                const data = JSON.parse(content);
                const name = file.replace('.json', '');

                // Check if it's a sub-profile (e.g., Work_Space1)
                const spaceMatch = name.match(/(.*)_Space(\d+)$/);

                if (spaceMatch) {
                    const groupName = spaceMatch[1];
                    const spaceIndex = parseInt(spaceMatch[2]);

                    if (!profilesMap.has(groupName)) {
                        profilesMap.set(groupName, {
                            name: groupName,
                            isGroup: true,
                            spaces: [],
                            saved_at: data.saved_at, // Use first found date
                            display_count: data.display_count
                        });
                    }

                    const group = profilesMap.get(groupName);
                    group.spaces.push(spaceIndex);
                    // Update date to latest if needed
                    if (new Date(data.saved_at) > new Date(group.saved_at)) {
                        group.saved_at = data.saved_at;
                    }
                } else {
                    // Regular profile
                    profilesMap.set(name, {
                        name: name,
                        isGroup: false,
                        ...data
                    });
                }
            } catch (e) {
                console.error(`Error parsing ${file}:`, e);
            }
        });

        const profiles = Array.from(profilesMap.values()).map(p => {
            if (p.isGroup) {
                p.space_count = p.spaces.length;
                // Calculate total windows from all sub-profiles
                let totalWindows = 0;
                p.spaces.forEach(i => {
                    const subProfileName = `${p.name}_Space${i}`;
                    const subFile = files.find(f => f === `${subProfileName}.json`);
                    if (subFile) {
                        try {
                            const subContent = fs.readFileSync(path.join(CONFIG_DIR, subFile), 'utf-8');
                            const subData = JSON.parse(subContent);
                            if (subData.windows) {
                                totalWindows += subData.windows.length;
                            }
                        } catch (e) { }
                    }
                });
                p.windows = { length: totalWindows };
            }
            return p;
        });

        // Sort by saved_at desc
        return profiles.sort((a, b) => new Date(b.saved_at) - new Date(a.saved_at));
    } catch (error) {
        console.error('Error getting profiles:', error);
        return [];
    }
}

function updateTrayMenu() {
    if (!tray) return;

    const profiles = getProfilesData();
    const template = [
        { label: 'Window Position Manager', enabled: false },
        { type: 'separator' },
        {
            label: 'Show Dashboard',
            click: () => {
                if (mainWindow) {
                    mainWindow.show();
                    mainWindow.focus();
                } else {
                    createWindow();
                }
            }
        },
        { type: 'separator' },
        { label: 'Restore Profile', enabled: false },
    ];

    if (profiles.length === 0) {
        template.push({ label: '(No profiles found)', enabled: false });
    } else {
        profiles.forEach(p => {
            template.push({
                label: p.name,
                click: async () => {
                    // Trigger restore
                    if (p.isGroup) {
                        execFile(SCRIPT_PATH, ['--restore-all', p.name, p.space_count.toString()], (error, stdout, stderr) => { });
                    } else {
                        execFile(SCRIPT_PATH, ['--restore', p.name], (error, stdout, stderr) => { });
                    }
                }
            });
        });
    }

    template.push(
        { type: 'separator' },
        {
            label: 'Quit',
            click: () => {
                app.isQuitting = true;
                app.quit();
            }
        }
    );

    const contextMenu = Menu.buildFromTemplate(template);
    tray.setContextMenu(contextMenu);
}

function createTray() {
    const icon = nativeImage.createFromPath(ICON_PATH).resize({ width: 16, height: 16 });
    tray = new Tray(icon);
    tray.setToolTip('Window Position Manager');
    updateTrayMenu();
}

app.whenReady().then(() => {
    createWindow();
    createTray();

    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) {
            createWindow();
        } else {
            mainWindow.show();
        }
    });
});

app.on('before-quit', () => {
    app.isQuitting = true;
});

// IPC Handlers
ipcMain.handle('get-profiles', async () => {
    return getProfilesData();
});

ipcMain.handle('save-profile', async (event, name) => {
    return new Promise((resolve, reject) => {
        // execute script with --save name
        // The script might pop up dialogs, which is handled by macOS.
        // We just wait for it to finish.
        execFile(SCRIPT_PATH, ['--save', name], (error, stdout, stderr) => {
            if (error) {
                console.error('Save error:', stderr);
                reject(stderr || error.message);
                return;
            }
            updateTrayMenu(); // Update menu after save
            resolve(stdout);
        });
    });
});

ipcMain.handle('save-profile-all', async (event, { name, count }) => {
    return new Promise((resolve, reject) => {
        execFile(SCRIPT_PATH, ['--save-all', name, count], (error, stdout, stderr) => {
            if (error) {
                console.error('Save all error:', stderr);
                reject(stderr || error.message);
                return;
            }
            updateTrayMenu(); // Update menu after save
            resolve(stdout);
        });
    });
});

ipcMain.handle('restore-profile', async (event, name) => {
    // Check if it is a group restore or single restore
    // The renderer should differentiate, but for simplicity we rely on the command
    // Actually, we need to know if we should use --restore or --restore-all
    // For now, let's look for files.

    // Easier approach: The UI calls a new method 'restore-profile-all' if it's a group.
    return new Promise((resolve, reject) => {
        execFile(SCRIPT_PATH, ['--restore', name], (error, stdout, stderr) => {
            if (error) {
                console.error('Restore error:', stderr);
                reject(stderr || error.message);
                return;
            }
            resolve(stdout);
        });
    });
});

ipcMain.handle('restore-profile-all', async (event, { name, count }) => {
    return new Promise((resolve, reject) => {
        execFile(SCRIPT_PATH, ['--restore-all', name, count], (error, stdout, stderr) => {
            if (error) {
                console.error('Restore all error:', stderr);
                reject(stderr || error.message);
                return;
            }
            resolve(stdout);
        });
    });
});


ipcMain.handle('delete-profile', async (event, name) => {
    try {
        const filePath = path.join(CONFIG_DIR, `${name}.json`);

        // Single file deletion
        if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
            updateTrayMenu(); // Update
            return true;
        }

        // Group deletion (e.g. "Work" -> "Work_Space1.json", "Work_Space2.json")
        const files = fs.readdirSync(CONFIG_DIR).filter(file => file.endsWith('.json'));
        let deletedAny = false;

        files.forEach(file => {
            // Check if file matches name_SpaceN pattern
            // e.g. name="Work", file="Work_Space1.json"
            const regex = new RegExp(`^${name}_Space\\d+\\.json$`);
            if (regex.test(file)) {
                try {
                    fs.unlinkSync(path.join(CONFIG_DIR, file));
                    deletedAny = true;
                } catch (e) {
                    console.error(`Failed to delete sub-profile ${file}:`, e);
                }
            }
        });

        if (deletedAny) updateTrayMenu();
        return deletedAny;
    } catch (error) {
        throw error;
    }
});

ipcMain.handle('get-current-display', async () => {
    return new Promise((resolve, reject) => {
        execFile(SCRIPT_PATH, ['--displays'], (error, stdout, stderr) => {
            if (error) {
                reject(stderr || error.message);
                return;
            }
            resolve(stdout);
        });
    });
});
