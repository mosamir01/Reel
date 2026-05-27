'use strict';

// ── State ─────────────────────────────────────────────────────────────────────

let state           = { items: [], outputFolder: null };
let selectedSection = 'all';
let currentFormat   = 'best';

// ── Utils ─────────────────────────────────────────────────────────────────────

const $ = id => document.getElementById(id);

function platformBadge(url) {
  const u = url.toLowerCase();
  if (u.includes('youtube.com') || u.includes('youtu.be')) return { label: 'YT', cls: 'badge-yt' };
  if (u.includes('instagram.com'))                         return { label: 'IG', cls: 'badge-ig' };
  if (u.includes('tiktok.com'))                            return { label: 'TT', cls: 'badge-tt' };
  if (u.includes('soundcloud.com'))                        return { label: 'SC', cls: 'badge-sc' };
  if (u.includes('twitter.com') || u.includes('x.com'))   return { label: 'X',  cls: 'badge-x'  };
  if (u.includes('reddit.com'))                            return { label: 'R',  cls: 'badge-rd' };
  if (u.includes('vimeo.com'))                             return { label: 'VI', cls: 'badge-vi' };
  if (u.includes('twitch.tv'))                             return { label: 'TW', cls: 'badge-tw' };
  return { label: '↓', cls: 'badge-dl' };
}

function tagClass(item) {
  switch (item.status) {
    case 'downloading': return 'tag-blue';
    case 'done':        return 'tag-green';
    case 'failed':      return 'tag-red';
    case 'queued':      return 'tag-amber';
    default:            return 'tag-muted';
  }
}

function statusLabel(item) {
  switch (item.status) {
    case 'queued':      return 'Queued';
    case 'fetching':    return 'Getting info...';
    case 'downloading': return `Downloading · ${Math.round(item.progress * 100)}%`;
    case 'converting':  return 'Converting';
    case 'done':        return 'Done';
    case 'failed':      return 'Failed';
    default:            return '';
  }
}

function formatLabel(fmt) {
  return fmt.toUpperCase();
}

function filteredItems() {
  const { items } = state;
  switch (selectedSection) {
    case 'downloading': return items.filter(i => ['fetching','downloading','converting'].includes(i.status));
    case 'queued':      return items.filter(i => i.status === 'queued');
    case 'completed':   return items.filter(i => ['done','failed'].includes(i.status));
    default:            return items;
  }
}

function sectionCount(section) {
  const { items } = state;
  switch (section) {
    case 'all':         return items.length;
    case 'downloading': return items.filter(i => ['fetching','downloading','converting'].includes(i.status)).length;
    case 'queued':      return items.filter(i => i.status === 'queued').length;
    case 'completed':   return items.filter(i => ['done','failed'].includes(i.status)).length;
    default: return 0;
  }
}

// ── Render ────────────────────────────────────────────────────────────────────

const SECTIONS = [
  { id: 'all',         label: 'All',         icon: iconTray()     },
  { id: 'downloading', label: 'Downloading',  icon: iconDownload() },
  { id: 'queued',      label: 'Queued',       icon: iconClock()    },
  { id: 'completed',   label: 'Completed',    icon: iconCheck()    },
];

function renderNav() {
  const list = $('navList');
  list.innerHTML = '';
  for (const s of SECTIONS) {
    const count = sectionCount(s.id);
    const item = document.createElement('div');
    item.className = 'nav-item' + (selectedSection === s.id ? ' active' : '');
    item.dataset.section = s.id;
    item.innerHTML = `
      <svg class="nav-icon" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5">${s.icon}</svg>
      <span>${s.label}</span>
      ${count > 0 ? `<span class="nav-badge">${count}</span>` : ''}
    `;
    item.addEventListener('click', () => {
      selectedSection = s.id;
      render();
    });
    list.appendChild(item);
  }
}

function renderDownloads() {
  const area  = $('scrollArea');
  const items = filteredItems();

  if (state.items.length === 0) {
    area.innerHTML = emptyStateHTML();
    return;
  }
  if (items.length === 0) {
    area.innerHTML = `
      <div class="section-empty">
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M2 3h12v10H2z"/></svg>
        <p>Nothing in ${SECTIONS.find(s => s.id === selectedSection)?.label ?? selectedSection}</p>
      </div>`;
    return;
  }

  area.innerHTML = items.map(rowHTML).join('');

  // Attach events after render
  area.querySelectorAll('[data-action]').forEach(btn => {
    const { action, id } = btn.dataset;
    btn.addEventListener('click', () => handleAction(action, id));
  });
}

function renderStatusBar() {
  const active    = state.items.filter(i => ['fetching','downloading','converting'].includes(i.status)).length;
  const completed = state.items.filter(i => i.status === 'done').length;
  const hasDone   = state.items.some(i => ['done','failed'].includes(i.status));

  const pills = $('statusPills');
  pills.innerHTML = '';

  if (active > 0)    pills.innerHTML += pill(active    + ' active',    'var(--amber)');
  if (completed > 0) pills.innerHTML += pill(completed + ' completed', 'var(--green)');

  const clearBtn = $('clearBtn');
  clearBtn.style.display = hasDone ? 'block' : 'none';
}

function pill(text, color) {
  return `<div class="status-pill">
    <div class="status-dot" style="background:${color}"></div>
    <span class="status-text">${text}</span>
  </div>`;
}

function renderFolderName() {
  const name = $('folderName');
  if (state.outputFolder) {
    const parts = state.outputFolder.replace(/\\/g, '/').split('/');
    name.textContent = parts.at(-1) || state.outputFolder;
  } else {
    name.textContent = 'No folder';
  }
}

function render() {
  renderNav();
  renderDownloads();
  renderStatusBar();
  renderFolderName();
}

// ── Row HTML ──────────────────────────────────────────────────────────────────

function rowHTML(item) {
  const { label, cls } = platformBadge(item.url);
  const tag            = `<span class="format-tag ${tagClass(item)}">${formatLabel(item.format)}</span>`;
  const status         = `<span class="dl-status">${statusLabel(item)}</span>`;

  let actions = '';
  switch (item.status) {
    case 'done':
      actions = `
        <button class="action-btn action-primary" data-action="open" data-id="${item.id}">Open</button>
        <button class="action-icon" data-action="remove" data-id="${item.id}" title="Remove">
          ${iconX()}
        </button>`;
      break;
    case 'failed':
      actions = `
        <button class="action-btn action-secondary" data-action="retry" data-id="${item.id}">Retry</button>
        <button class="action-icon" data-action="remove" data-id="${item.id}" title="Remove">
          ${iconX()}
        </button>`;
      break;
    default:
      actions = `<button class="action-btn action-secondary" data-action="cancel" data-id="${item.id}">Cancel</button>`;
  }

  let extra = '';
  if (item.status === 'downloading') {
    const pct = Math.round(item.progress * 100);
    const fill = Math.round(item.progress * 100);
    extra = `
      <div class="dl-progress">
        <div class="progress-track"><div class="progress-fill" style="width:${fill}%"></div></div>
        <div class="progress-meta">
          <span>${pct}%</span>
          ${item.speed ? `<span class="progress-sep">·</span><span>${item.speed}</span>` : ''}
          ${item.eta   ? `<span class="progress-sep">·</span><span>ETA ${item.eta}</span>` : ''}
        </div>
      </div>`;
  } else if (item.status === 'converting') {
    extra = `<div class="dl-converting">Converting...</div>`;
  } else if (item.status === 'failed' && item.errorMessage) {
    extra = `<div class="dl-error">${escHtml(item.errorMessage)}</div>`;
  }

  return `
    <div class="dl-row">
      <div class="dl-row-main">
        <div class="platform-badge ${cls}">${label}</div>
        <div class="dl-info">
          <div class="dl-title">${escHtml(item.title)}</div>
          <div class="dl-meta">${tag}${status}</div>
        </div>
        <div class="dl-actions">${actions}</div>
      </div>
      ${extra}
    </div>`;
}

// ── Empty state ───────────────────────────────────────────────────────────────

const SITES = ['YouTube', 'TikTok', 'Instagram', 'Twitter / X', 'Reddit', 'Vimeo', 'SoundCloud', 'Twitch', '+1000 more'];

function emptyStateHTML() {
  const chips = SITES.map(s => `<span class="empty-site">${s}</span>`).join('');
  return `
    <div class="empty-state">
      <div class="empty-icon-wrap">
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.2">
          <path d="M8 2v9m-4-4 4 4 4-4"/><path d="M2 14h12"/>
        </svg>
      </div>
      <div class="empty-text">
        <div class="empty-title">Paste any video or audio URL</div>
        <div class="empty-sub">Copy a link from your browser and paste it above.<br>Reel handles the rest.</div>
      </div>
      <div class="empty-sites">${chips}</div>
    </div>`;
}

// ── Actions ───────────────────────────────────────────────────────────────────

function handleAction(action, id) {
  switch (action) {
    case 'open':   window.reel.openFile(id);       break;
    case 'cancel': window.reel.cancelDownload(id); break;
    case 'remove': window.reel.removeDownload(id); break;
    case 'retry':  window.reel.retryDownload(id);  break;
  }
}

function addDownload() {
  const url = $('urlInput').value.trim();
  if (!url) return;
  window.reel.addDownload(url, currentFormat);
  $('urlInput').value = '';
  updateClearBtn();
}

function showFolderModal()  { $('folderModal').classList.add('visible');    }
function hideFolderModal()  { $('folderModal').classList.remove('visible'); }

function updateClearBtn() {
  $('urlClear').style.display = $('urlInput').value ? 'block' : 'none';
}

// ── SVG icons ─────────────────────────────────────────────────────────────────

function iconTray()     { return '<path d="M2 3h12v10H2z"/><path d="M5 3V1m6 2V1"/>'; }
function iconDownload() { return '<path d="M8 2v9m-4-4 4 4 4-4"/><path d="M3 14h10"/>'; }
function iconClock()    { return '<circle cx="8" cy="8" r="6"/><path d="M8 5v3l2 2"/>'; }
function iconCheck()    { return '<path d="M3 8l4 4 6-6"/>'; }
function iconX() {
  return `<svg viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.5">
    <path d="M2 2l8 8M10 2l-8 8"/>
  </svg>`;
}

function escHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/\n/g, '<br>');
}

// ── Init ──────────────────────────────────────────────────────────────────────

async function init() {
  state = await window.reel.getState();
  render();

  // IPC listeners
  window.reel.onStateUpdate(data => { state = data; render(); });
  window.reel.onShowFolderSetup(showFolderModal);

  // URL input
  const urlInput = $('urlInput');
  urlInput.addEventListener('input', updateClearBtn);
  urlInput.addEventListener('keydown', e => { if (e.key === 'Enter') addDownload(); });

  $('urlClear').addEventListener('click', () => {
    urlInput.value = '';
    urlInput.focus();
    updateClearBtn();
  });

  // Download button
  $('dlBtn').addEventListener('click', addDownload);

  // Format picker
  $('formatPicker').addEventListener('click', e => {
    const btn = e.target.closest('[data-fmt]');
    if (!btn) return;
    currentFormat = btn.dataset.fmt;
    $('formatPicker').querySelectorAll('.format-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
  });

  // Clear completed
  $('clearBtn').addEventListener('click', () => window.reel.clearCompleted());

  // Folder gear
  $('gearBtn').addEventListener('click', () => window.reel.pickFolder());
  $('folderName').addEventListener('click', () => window.reel.openFolder());

  // Folder modal
  $('modalPickBtn').addEventListener('click', async () => {
    const folder = await window.reel.pickFolder();
    if (folder) hideFolderModal();
  });
}

document.addEventListener('DOMContentLoaded', init);
