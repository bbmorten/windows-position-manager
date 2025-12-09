const profilesGrid = document.getElementById('profiles-grid');
const saveBtn = document.getElementById('save-btn');
const newProfileInput = document.getElementById('new-profile-name');
const displayText = document.getElementById('display-text');
const template = document.getElementById('profile-card-template');
const tutorialModal = document.getElementById('tutorial-modal');
const closeTutorialBtn = document.getElementById('close-tutorial');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    loadProfiles();
    updateDisplayInfo();
    checkTutorial();
    updateDisplayInfo();
    checkTutorial();

    // Listen for display changes (hot-plug)
    window.api.onDisplayMetricsChanged(() => {
        console.log('Display metrics changed, updating info...');
        updateDisplayInfo();
    });
});

function checkTutorial() {
    const seen = localStorage.getItem('wpm-tutorial-seen');
    if (!seen) {
        // Show modal after a short delay
        setTimeout(() => {
            tutorialModal.classList.remove('hidden');
        }, 500);
    }
}

closeTutorialBtn.addEventListener('click', () => {
    tutorialModal.classList.add('hidden');
    localStorage.setItem('wpm-tutorial-seen', 'true');
});

async function loadProfiles() {
    try {
        const profiles = await window.api.getProfiles();
        renderProfiles(profiles);
    } catch (err) {
        console.error(err);
        profilesGrid.innerHTML = `<div class="loading-spinner" style="color: var(--danger-color)">Error loading profiles</div>`;
    }
}

function renderProfiles(profiles) {
    profilesGrid.innerHTML = '';

    if (profiles.length === 0) {
        profilesGrid.innerHTML = `
            <div class="loading-spinner" style="grid-column: 1/-1;">
                No profiles found. Save your first layout!
            </div>`;
        return;
    }

    profiles.forEach(profile => {
        const clone = template.content.cloneNode(true);
        const card = clone.querySelector('.profile-card');

        clone.querySelector('.profile-name').textContent = profile.name.replace(/_/g, ' ');

        // Format date safely
        let dateStr = profile.saved_at;
        try {
            // Try to make it shorter if it's the long AppleScript string
            // "Monday, December 8, 2025 at 10:30:00 AM" -> "Dec 8, 10:30 AM"
            const date = new Date(profile.saved_at.replace(' at ', ' '));
            if (!isNaN(date.getTime())) {
                dateStr = date.toLocaleDateString(undefined, {
                    month: 'short',
                    day: 'numeric',
                    hour: 'numeric',
                    minute: '2-digit'
                });
            }
        } catch (e) {
            // keep original string
        }
        clone.querySelector('.profile-date').textContent = dateStr;

        // Count windows/spaces/displays
        const winCount = profile.windows ? profile.windows.length : 0;
        clone.querySelector('.window-count').textContent = winCount;
        clone.querySelector('.display-count').textContent = profile.display_count || 1;
        clone.querySelector('.space-count').textContent = profile.space_count || 1;

        // Populate App List
        const appList = clone.querySelector('.app-list');
        const toggleBtn = clone.querySelector('.toggle-apps-btn');

        if (profile.windows && profile.windows.length > 0) {
            // Container structure:
            // [Tabs Header]
            // [Active Tab Content]

            // Group by Space
            const spaces = {};
            profile.windows.forEach(w => {
                const spaceId = w.space || 1;
                if (!spaces[spaceId]) spaces[spaceId] = [];
                spaces[spaceId].push(w);
            });

            const renderAppItem = async (w, container) => {
                const appEl = document.createElement('div');
                appEl.className = 'app-icon-item';
                appEl.title = `${w.app}\n${w.window || ''}\n${w.width}x${w.height} @ ${w.x},${w.y}`;

                // Use simple colored placeholder with first letter
                const firstLetter = w.app[0].toUpperCase();
                const colors = ['#3b82f6', '#8b5cf6', '#ec4899', '#f59e0b', '#10b981', '#06b6d4', '#6366f1'];
                const colorIndex = w.app.charCodeAt(0) % colors.length;
                const bgColor = colors[colorIndex];

                appEl.innerHTML = `
                    <div class="icon-placeholder" style="background: ${bgColor}; color: white; font-weight: 600; font-size: 20px; display: flex; align-items: center; justify-content: center;">
                        ${firstLetter}
                    </div>
                    <span class="app-label">${w.app}</span>
                `;
                container.appendChild(appEl);
            };

            // Create Tabs and Contents
            const spaceIds = Object.keys(spaces).sort((a, b) => parseInt(a) - parseInt(b));

            // Container for Monitor Tabs
            const monitorTabsHeader = document.createElement('div');
            monitorTabsHeader.className = 'tabs-header monitor-tabs';

            // Container for Space Tabs (Sub-tabs)
            const spaceTabsHeader = document.createElement('div');
            spaceTabsHeader.className = 'tabs-header space-tabs';
            spaceTabsHeader.style.marginTop = '8px';
            spaceTabsHeader.style.borderBottom = 'none';

            // Content Area
            const tabsContent = document.createElement('div');
            tabsContent.className = 'tabs-content';

            appList.appendChild(monitorTabsHeader);
            appList.appendChild(spaceTabsHeader);
            appList.appendChild(tabsContent);

            const displays = profile.displays || [{ name: "Unknown Display", x: 0, width: 99999 }];

            // Helper: Get Windows for (Monitor, Space)
            const getWindowsFor = (display, spaceId) => {
                const spaceWindows = spaces[spaceId] || [];
                console.log(`[RENDER] Checking ${spaceWindows.length} windows for display "${display.name}" (x:${display.x}-${display.x + display.width}, y:${display.y}-${display.y + display.height})`);

                const matched = spaceWindows.filter(w => {
                    // For side-by-side displays, X coordinate is the primary indicator
                    // Use center_x if available, otherwise calculate from x + width/2
                    const wx = w.center_x !== undefined ? w.center_x : (w.x + (w.width || 0) / 2);

                    // Check if window's horizontal center is within this display's X range
                    const inXRange = wx >= display.x && wx < (display.x + display.width);

                    // For Y, be more lenient - windows can extend beyond display bounds
                    // Just check if window origin is somewhere reasonable (not wildly off)
                    const wy = w.y;
                    const displayTopY = display.y;
                    const displayBottomY = display.y + display.height;

                    // Window is "on" this display if it starts within or slightly outside the Y bounds
                    const inYRange = wy >= (displayTopY - 200) && wy < (displayBottomY + 500);

                    const matches = inXRange && inYRange;

                    if (wx > 2000 || wy > 500 || !matches) {
                        console.log(`[RENDER]   ${w.app}: x=${w.x} center_x=${wx} y=${wy} - X:${inXRange} Y:${inYRange} = ${matches}`);
                    }

                    return matches;
                });

                console.log(`[RENDER] Matched ${matched.length} windows for "${display.name}"`);
                return matched;
            };

            // 1. Render Monitor Tabs
            const loadMonitor = (display) => {
                // Clear sub-tabs and content
                spaceTabsHeader.innerHTML = '';
                tabsContent.innerHTML = '';

                // Find which spaces have content on THIS monitor
                const activeSpaces = Object.keys(spaces).filter(spaceId => {
                    const wins = getWindowsFor(display, spaceId);
                    return wins.length > 0;
                }).sort((a, b) => parseInt(a) - parseInt(b));

                if (activeSpaces.length === 0) {
                    tabsContent.innerHTML = '<div class="empty-state">No windows captured on this monitor.</div>';
                    return;
                }

                // 2. Render Space Sub-Tabs
                const loadSpace = (spaceId) => {
                    tabsContent.innerHTML = '';
                    const grid = document.createElement('div');
                    grid.className = 'apps-grid';

                    const wins = getWindowsFor(display, spaceId);
                    wins.forEach(w => renderAppItem(w, grid));

                    tabsContent.appendChild(grid);
                };

                activeSpaces.forEach((spaceId, idx) => {
                    const sBtn = document.createElement('button');
                    sBtn.className = 'tab-btn space-tab-btn';
                    sBtn.textContent = `Space ${spaceId}`;
                    if (idx === 0) sBtn.classList.add('active');

                    sBtn.onclick = (e) => {
                        spaceTabsHeader.querySelectorAll('.space-tab-btn').forEach(b => b.classList.remove('active'));
                        e.target.classList.add('active');
                        loadSpace(spaceId);
                    };
                    spaceTabsHeader.appendChild(sBtn);
                });

                // Load first space
                if (activeSpaces.length > 0) loadSpace(activeSpaces[0]);
            };

            displays.forEach((disp, idx) => {
                const mBtn = document.createElement('button');
                mBtn.className = 'tab-btn monitor-tab-btn';
                mBtn.textContent = disp.name || `Monitor ${idx + 1}`;
                if (idx === 0) mBtn.classList.add('active');

                mBtn.onclick = (e) => {
                    monitorTabsHeader.querySelectorAll('.monitor-tab-btn').forEach(b => b.classList.remove('active'));
                    e.target.classList.add('active');
                    loadMonitor(disp);
                };
                monitorTabsHeader.appendChild(mBtn);
            });

            // Init
            if (displays.length > 0) loadMonitor(displays[0]);





            toggleBtn.onclick = () => {
                const isHidden = appList.classList.contains('hidden');
                if (isHidden) {
                    appList.classList.remove('hidden');
                    toggleBtn.textContent = 'Hide Apps';
                } else {
                    appList.classList.add('hidden');
                    toggleBtn.textContent = 'Show Apps';
                }
            };
        } else {
            toggleBtn.textContent = 'No Apps';
            toggleBtn.disabled = true;
            toggleBtn.style.opacity = '0.5';
        }

        // Actions
        const restoreBtn = clone.querySelector('.restore-btn');
        restoreBtn.onclick = async () => {
            restoreBtn.textContent = 'Restoring...';
            restoreBtn.disabled = true;
            try {
                if (profile.isGroup) {
                    await window.api.restoreProfileAll(profile.name, profile.space_count);
                } else {
                    await window.api.restoreProfile(profile.name);
                }
            } catch (e) {
                alert('Failed to restore: ' + e);
            } finally {
                restoreBtn.textContent = 'Restore Layout';
                restoreBtn.disabled = false;
            }
        };

        const deleteBtn = clone.querySelector('.delete-btn');
        deleteBtn.onclick = async () => {
            if (confirm(`Delete profile "${profile.name}"?`)) {
                await window.api.deleteProfile(profile.name);
                loadProfiles();
            }
        };

        profilesGrid.appendChild(clone);
    });
}

async function updateDisplayInfo() {
    try {
        const info = await window.api.getCurrentDisplay();
        // Parse info from script output
        // "Total screens: 2..."
        const match = info.match(/Total screens: (\d+)/);
        if (match) {
            displayText.textContent = `${match[1]} Connected Display(s)`;
        } else {
            displayText.textContent = 'Display Info Ready';
        }
    } catch (e) {
        displayText.textContent = 'Unknown Display Config';
    }
}

saveBtn.addEventListener('click', async () => {
    const name = newProfileInput.value.trim();
    if (!name) {
        alert('Please enter a profile name');
        return;
    }

    const isMultiSpace = document.getElementById('multi-space-check').checked;

    // UI Loading state
    const originalText = saveBtn.innerHTML;
    saveBtn.textContent = isMultiSpace ? 'Detecting & Saving All Spaces...' : 'Saving...';
    saveBtn.disabled = true;

    try {
        if (isMultiSpace) {
            if (confirm(`You are about to save ALL desktop spaces (auto-detected).\\n\\nIMPORTANT:\\n1. Ensure you are currently on Space 1.\\n2. Do not touch the keyboard/mouse while running.\\n\\nThe app will automatically detect and capture all your spaces.`)) {
                // Pass 'auto' to trigger automatic detection
                await window.api.saveProfileAll(name, 'auto');
            }
        } else {
            await window.api.saveProfile(name);
        }
        newProfileInput.value = '';
        loadProfiles();
    } catch (e) {
        alert('Error saving profile: ' + e);
    } finally {
        saveBtn.innerHTML = originalText;
        saveBtn.disabled = false;
    }
});

// Allow Enter key to save
newProfileInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        saveBtn.click();
    }
});
