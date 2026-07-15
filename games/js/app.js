// Mini Arcade — hub shell.
// The game catalog is data-driven: it is fetched from manifest.json at runtime
// and each game is a module loaded on demand via dynamic import(). Ship a new
// manifest + module and every client picks it up online — no rebuild needed.

import { PREVIEWS } from './previews.js';

const MANIFEST_URL = 'manifest.json';
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
    const res = await fetch(MANIFEST_URL, { cache: 'no-cache' });
    if (!res.ok) throw new Error('http ' + res.status);
    const fresh = await res.json();
    const changed = !cached || cached.version !== fresh.version;
    localStorage.setItem(LS_MANIFEST, JSON.stringify(fresh));
    renderGrid(fresh);
    if (changed && cached) announceUpdate(cached.version, fresh.version);
    else if (changed) markSeen(fresh.version);
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

function readCache() {
  try { return JSON.parse(localStorage.getItem(LS_MANIFEST)); }
  catch { return null; }
}
function markSeen(v) { localStorage.setItem(LS_SEENVER, v); }

function announceUpdate(oldV, newV) {
  const added = countNewGames();
  const label = added > 0 ? `${added} new game${added > 1 ? 's' : ''} added!` : `Updated to v${newV}`;
  toast(label, { label: 'Refresh', onClick: () => location.reload() });
  markSeen(newV);
}
function countNewGames() {
  // best-effort: compare ids present now vs last catalog render
  return 0;
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
    const art = (PREVIEWS[g.id] && PREVIEWS[g.id](g)) || defaultArt(g);
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
    const mod = await import(`../${g.module}?v=${encodeURIComponent(state.catalog.version)}`);
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
  const before = state.catalog && state.catalog.version;
  try {
    const res = await fetch(MANIFEST_URL, { cache: 'no-store' });
    const fresh = await res.json();
    localStorage.setItem(LS_MANIFEST, JSON.stringify(fresh));
    if (fresh.version !== before) {
      renderGrid(fresh);
      if ('serviceWorker' in navigator) {
        const reg = await navigator.serviceWorker.getRegistration();
        reg && reg.update();
      }
      toast(`Updated to v${fresh.version}!`, { label: 'Reload', onClick: () => location.reload() });
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
