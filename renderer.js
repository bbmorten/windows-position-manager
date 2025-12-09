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
            // Group by app name
            const appMap = new Map();
            profile.windows.forEach(w => {
                appMap.set(w.app, (appMap.get(w.app) || 0) + 1);
            });

            appMap.forEach((count, appName) => {
                const item = document.createElement('div');
                item.className = 'app-item';
                item.innerHTML = `
                    <span class="app-name">${appName}</span>
                    ${count > 1 ? `<span class="app-badge">${count}</span>` : ''}
                `;
                appList.appendChild(item);
            });

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
            toggleBtn.style.display = 'none';
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
    const spaceCount = parseInt(document.getElementById('space-count').value) || 1;

    // UI Loading state
    const originalText = saveBtn.innerHTML;
    saveBtn.textContent = isMultiSpace ? 'Saving All Spaces...' : 'Saving...';
    saveBtn.disabled = true;

    try {
        if (isMultiSpace) {
            if (confirm(`You are about to save ${spaceCount} spaces.\n\nIMPORTANT:\n1. Ensure you are currently on Space 1.\n2. Do not touch the keyboard/mouse while running.\n\nThe app will simulate swiping right to capture each space.`)) {
                await window.api.saveProfileAll(name, spaceCount);
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
