// Mini Arcade — hub shell.
// The game catalog is data-driven: it is fetched from manifest.json at runtime
// and each game is a module loaded on demand via dynamic import(). Ship a new
// manifest + module and every client picks it up online — no rebuild needed.

import { PREVIEWS } from './previews.js';

// Optional runtime config (set by a bundled config.js in the native app shell):
//   window.ARCADE_CONFIG = { remoteBase: "https://you.github.io/docs/games" }
// When remoteBase is set, the app loads its bundled catalog for offline play and
// *overlays* extra/updated games fetched from that published URL — so new games
// ship without an App Store update. When unset (plain web/PWA), everything is
// same-origin and the manifest.json in this folder is the single source.
const CFG = (typeof window !== 'undefined' && window.ARCADE_CONFIG) || {};
const REMOTE_BASE = (CFG.remoteBase || '').replace(/\/+$/, '');

const MANIFEST_URL = 'manifest.json';
const REMOTE_MANIFEST_URL = REMOTE_BASE ? REMOTE_BASE + '/manifest.json' : MANIFEST_URL;
const LS_MANIFEST = 'ma:manifest';       // cached catalog for offline launch
const LS_SEENVER = 'ma:seenver';

const $ = (s, r = document) => r.querySelector(s);
const el = (tag, cls, html) => {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (html != null) n.innerHTML = html;
  return n;
};

const state = { catalog: null, current: null, cleanup: null };

/* ---------------- Toast ---------------- */
let toastTimer;
function toast(msg, cta) {
  const t = $('#toast');
  t.innerHTML = msg + (cta ? ` <span class="toast-cta">${cta.label}</span>` : '');
  t.classList.remove('hidden');
  requestAnimationFrame(() => t.classList.add('show'));
  clearTimeout(toastTimer);
  if (cta) {
    $('.toast-cta', t).onclick = () => { hideToast(); cta.onClick(); };
  }
  toastTimer = setTimeout(hideToast, cta ? 7000 : 2600);
}
function hideToast() {
  const t = $('#toast');
  t.classList.remove('show');
  setTimeout(() => t.classList.add('hidden'), 250);
}

/* ---------------- Manifest / catalog ---------------- */
async function loadCatalog() {
  // Instant paint from cache when available, then refresh from network.
  const cached = readCache();
  if (cached) renderGrid(cached);
  else renderSkeleton();

  try {
    // 1) local/bundled catalog — this is the offline base set.
    const res = await fetch(MANIFEST_URL, { cache: 'no-cache' });
    if (!res.ok) throw new Error('http ' + res.status);
    const local = await res.json();
    local.games.forEach(g => { g._base = ''; });

    // 2) remote overlay — extra or updated games from the published URL.
    const merged = await overlayRemote(local);

    const prevIds = cached ? new Set(cached.games.map(g => g.id)) : null;
    const changed = !cached || cached.version !== merged.version ||
      merged.games.length !== (cached.games ? cached.games.length : 0);
    localStorage.setItem(LS_MANIFEST, JSON.stringify(merged));
    renderGrid(merged);

    const added = prevIds ? merged.games.filter(g => !prevIds.has(g.id)).length : 0;
    if (changed && cached) announceUpdate(added, merged.version);
    else markSeen(merged.version);
  } catch (e) {
    if (!cached) {
      $('#grid').innerHTML =
        `<div style="grid-column:1/-1;text-align:center;padding:40px 10px;color:#b79a7c;font-weight:800">
           Couldn't load games.<br>Check your connection and tap ⟳.
         </div>`;
    }
    // offline & we already showed the cached grid — that's fine.
  }
  updateNetBadge();
}

// Fetch the remote catalog and merge in games not present locally (and refresh
// metadata for ones that are). Bundled games keep their local module so they
// stay playable offline; brand-new games load their module from REMOTE_BASE.
async function overlayRemote(local) {
  if (!REMOTE_BASE || !navigator.onLine) return local;
  try {
    const res = await fetch(REMOTE_MANIFEST_URL, { cache: 'no-store' });
    if (!res.ok) return local;
    const remote = await res.json();
    const byId = new Map(local.games.map(g => [g.id, g]));
    remote.games.forEach(rg => {
      if (byId.has(rg.id)) return;            // keep bundled (offline-capable) version
      rg._base = REMOTE_BASE;                  // new game → load module from remote
      local.games.push(rg);
    });
    // adopt the remote catalog version so update prompts track the publisher
    if (remote.version) local.version = remote.version;
    if (remote.title) local.title = remote.title;
  } catch { /* offline / blocked — bundled set is fine */ }
  return local;
}

function readCache() {
  try { return JSON.parse(localStorage.getItem(LS_MANIFEST)); }
  catch { return null; }
}
function markSeen(v) { localStorage.setItem(LS_SEENVER, v); }

function announceUpdate(added, newV) {
  const label = added > 0 ? `🎉 ${added} new game${added > 1 ? 's' : ''} added!` : `Updated to v${newV}`;
  if (added > 0) toast(label);
  markSeen(newV);
}

/* ---------------- Rendering ---------------- */
function renderSkeleton() {
  const grid = $('#grid');
  grid.innerHTML = '';
  for (let i = 0; i < 6; i++) {
    grid.appendChild(el('div', 'card skel', '<div class="card-inner"></div>'));
  }
}

function renderGrid(cat) {
  state.catalog = cat;
  document.title = `${cat.title || 'Mini Arcade'} — Offline Minigames`;
  $('#verLabel').textContent = `${cat.title || 'Mini Arcade'} · v${cat.version}`;
  $('#drawerVer').textContent = `v${cat.version}`;
  $('#drawerTag').textContent = cat.tagline || '';

  const grid = $('#grid');
  grid.innerHTML = '';
  cat.games.forEach((g, i) => {
    const card = el('div', 'card');
    card.style.animationDelay = (i * 45) + 'ms';
    const art = g.svg || (PREVIEWS[g.id] && PREVIEWS[g.id](g)) || defaultArt(g);
    const badges = (g.tags || []).map(t => `<span class="badge">${t}</span>`).join('');
    card.innerHTML = `
      <div class="card-inner" style="background:${g.color}">
        <div class="card-art">${art}</div>
        ${badges ? `<div class="card-badges">${badges}</div>` : ''}
        <div class="card-head">
          <div class="card-title" style="color:${g.titleColor || '#fff'}">${g.title}</div>
          <div class="card-underline" style="background:${g.accent || '#fff'}"></div>
        </div>
      </div>`;
    card.onclick = () => openGame(g);
    grid.appendChild(card);
  });
}

function defaultArt(g) {
  const icon = g.icon || '🎮';
  return `<div style="position:absolute;inset:0;display:flex;align-items:center;
    justify-content:center;font-size:64px;filter:drop-shadow(0 4px 6px rgba(0,0,0,.2))">${icon}</div>`;
}

/* ---------------- Router ---------------- */
async function openGame(g) {
  state.current = g;
  $('#gameTitle').textContent = g.title;
  const stage = $('#stage');
  stage.innerHTML = `<div style="margin:auto;color:#b79a7c;font-weight:800">Loading…</div>`;
  show('player');
  history.pushState({ game: g.id }, '', '#' + g.id);

  try {
    const mod = await import(moduleURL(g));
    stage.innerHTML = '';
    const api = makeApi(g);
    const ret = mod.mount(stage, api);
    state.cleanup = typeof ret === 'function' ? ret : (ret && ret.cleanup) || null;
    state._restart = (ret && ret.restart) || null;
  } catch (e) {
    console.error(e);
    stage.innerHTML =
      `<div style="margin:auto;text-align:center;color:#b79a7c;font-weight:800;padding:30px">
         This game failed to load.<br><small>${(e && e.message) || e}</small>
       </div>`;
  }
}

// Resolve a game's module URL. Absolute (http) modules load as-is; games from
// the remote overlay load from REMOTE_BASE; bundled games load locally.
function moduleURL(g) {
  const v = `?v=${encodeURIComponent(state.catalog.version || '1')}`;
  if (/^https?:/i.test(g.module)) return g.module + v;
  if (g._base) return `${g._base}/${g.module}${v}`;
  return `../${g.module}${v}`;
}

function makeApi(g) {
  const ns = 'ma:' + g.id + ':';
  return {
    meta: g,
    storage: {
      get(k, d) { const v = localStorage.getItem(ns + k); return v == null ? d : JSON.parse(v); },
      set(k, v) { localStorage.setItem(ns + k, JSON.stringify(v)); },
    },
    toast,
    // let modules build consistent chrome
    h: el,
  };
}

function closeGame(pop = true) {
  if (state.cleanup) { try { state.cleanup(); } catch {} state.cleanup = null; }
  state._restart = null;
  state.current = null;
  $('#stage').innerHTML = '';
  show('home');
  if (pop && location.hash) history.pushState({}, '', location.pathname + location.search);
}

function show(which) {
  $('#home').classList.toggle('hidden', which !== 'home');
  $('#player').classList.toggle('hidden', which !== 'player');
}

/* ---------------- Drawer ---------------- */
function openDrawer() { $('#drawer').classList.remove('hidden'); }
function closeDrawer() { $('#drawer').classList.add('hidden'); }

/* ---------------- Network badge ---------------- */
function updateNetBadge() {
  const b = $('#netBadge');
  const on = navigator.onLine;
  b.textContent = on ? 'Online' : 'Offline';
  b.className = 'net-badge ' + (on ? 'on' : 'off');
}

/* ---------------- Wire up ---------------- */
function init() {
  $('#menuBtn').onclick = openDrawer;
  $('#drawer').querySelectorAll('[data-close]').forEach(n => n.onclick = closeDrawer);
  $('#backBtn').onclick = () => history.back();
  $('#restartBtn').onclick = () => { if (state._restart) state._restart(); else if (state.current) openGame(state.current); };

  $('#refreshBtn').onclick = doUpdateCheck;
  $('#drawerUpdate').onclick = () => { closeDrawer(); doUpdateCheck(); };
  $('#drawerReset').onclick = () => {
    closeDrawer();
    Object.keys(localStorage).filter(k => k.startsWith('ma:') && !k.startsWith('ma:manifest') && !k.startsWith('ma:seenver'))
      .forEach(k => localStorage.removeItem(k));
    toast('High scores cleared');
  };

  window.addEventListener('online', updateNetBadge);
  window.addEventListener('offline', updateNetBadge);
  window.addEventListener('popstate', (e) => {
    const id = (location.hash || '').replace('#', '');
    if (id && state.catalog) {
      const g = state.catalog.games.find(x => x.id === id);
      if (g && (!state.current || state.current.id !== id)) { openGame(g); return; }
    }
    if (!id) closeGame(false);
  });

  loadCatalog().then(() => {
    // deep link support
    const id = (location.hash || '').replace('#', '');
    if (id && state.catalog) {
      const g = state.catalog.games.find(x => x.id === id);
      if (g) openGame(g);
    }
  });

  registerSW();
}

async function doUpdateCheck() {
  toast('Checking for updates…');
  const beforeIds = new Set((state.catalog?.games || []).map(g => g.id));
  const beforeVer = state.catalog?.version;
  try {
    const res = await fetch(MANIFEST_URL, { cache: 'no-store' });
    const local = await res.json();
    local.games.forEach(g => { g._base = ''; });
    const fresh = await overlayRemote(local);
    localStorage.setItem(LS_MANIFEST, JSON.stringify(fresh));
    const added = fresh.games.filter(g => !beforeIds.has(g.id)).length;
    if (added > 0 || fresh.version !== beforeVer) {
      renderGrid(fresh);
      if ('serviceWorker' in navigator) {
        const reg = await navigator.serviceWorker.getRegistration();
        reg && reg.update();
      }
      toast(added > 0 ? `🎉 ${added} new game${added > 1 ? 's' : ''} added!` : `Updated to v${fresh.version} ✓`);
    } else {
      toast('You have the latest games ✓');
    }
  } catch {
    toast(navigator.onLine ? 'Update check failed' : 'You are offline');
  }
}

function registerSW() {
  if (!('serviceWorker' in navigator)) return;
  navigator.serviceWorker.register('sw.js').then(reg => {
    reg.addEventListener('updatefound', () => {
      const nw = reg.installing;
      nw && nw.addEventListener('statechange', () => {
        if (nw.state === 'installed' && navigator.serviceWorker.controller) {
          toast('App updated', { label: 'Reload', onClick: () => location.reload() });
        }
      });
    });
  }).catch(() => {});
}

init();
