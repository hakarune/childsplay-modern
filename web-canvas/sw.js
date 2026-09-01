/* Childsplay Modern - service worker.
 *
 * Strategy: stale-while-revalidate for every same-origin GET. The app
 * loads instantly from cache and works fully offline once visited; the
 * next load after a deploy picks up fresh files. Navigations fall back to
 * the cached start page when offline.
 *
 * Bump CACHE on a release if you want old entries evicted immediately
 * rather than lazily refreshed.
 */
const CACHE = 'cp-cache-87f25d49c1';

// The app shell - enough to boot the menu offline even if a game module
// was never opened. Game modules and assets are cached on first use.
const SHELL = [
  '.',
  'index.html',
  'manifest.webmanifest',
  'css/style.css',
  'js/engine.js',
  'js/util.js',
  'js/theme.js',
  'js/tts.js',
  'js/menu.js',
  'js/main.js',
  'js/games/index.js',
  'icons/icon.svg',
  'icons/icon-192.png',
  'icons/icon-512.png',
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE)
      .then((c) => c.addAll(SHELL.map((u) => new Request(u, { cache: 'reload' }))))
      .catch(() => {})               // a missing shell file must not abort install
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;   // let cross-origin (fonts CDN etc.) pass through

  e.respondWith(
    caches.open(CACHE).then(async (cache) => {
      const cached = await cache.match(req, { ignoreSearch: false });
      const network = fetch(req)
        .then((res) => {
          if (res && res.ok && res.type === 'basic') cache.put(req, res.clone());
          return res;
        })
        .catch(() => null);

      if (cached) {
        network;                       // refresh in the background
        return cached;
      }
      const res = await network;
      if (res) return res;
      // offline, nothing cached: for a page navigation, serve the shell
      if (req.mode === 'navigate') {
        return (await cache.match('index.html')) || (await cache.match('.')) || Response.error();
      }
      return Response.error();
    }),
  );
});
