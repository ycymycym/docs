// Mini Arcade service worker — offline support + online updates.
// Strategy:
//   • core shell  → precached, served cache-first (fast launch, works offline)
//   • manifest    → network-first (so new games/updates come through when online)
//   • everything  → stale-while-revalidate (instant, refreshes in background)
// Game modules are imported with a ?v=<version> query, so a new catalog version
// is a new URL → always re-fetched and re-cached.

const CACHE = 'mini-arcade-v1';
const CORE = [
  './',
  './index.html',
  './css/style.css',
  './js/app.js',
  './js/previews.js',
  './js/games/_ui.js',
  './app.webmanifest',
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const { request } = e;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== location.origin) return;

  if (url.pathname.endsWith('manifest.json')) {
    e.respondWith(networkFirst(request));
    return;
  }
  e.respondWith(staleWhileRevalidate(request));
});

async function networkFirst(req) {
  const cache = await caches.open(CACHE);
  try {
    const res = await fetch(req, { cache: 'no-store' });
    if (res && res.ok) cache.put(req, res.clone());
    return res;
  } catch {
    const cached = await cache.match(req);
    return cached || new Response('{"offline":true}', { headers: { 'Content-Type': 'application/json' } });
  }
}

async function staleWhileRevalidate(req) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(req);
  const fetching = fetch(req).then(res => {
    if (res && res.ok) cache.put(req, res.clone());
    return res;
  }).catch(() => cached);
  return cached || fetching;
}
