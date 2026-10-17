/* Bump VERSION when publishing changed app files. Do not activate over an open demo. */
const VERSION = 'v3';
const SCOPE_URL = new URL(self.registration.scope);
const CACHE_PREFIX = `foodienoms-fresh-${encodeURIComponent(SCOPE_URL.pathname)}-`;
const CACHE_NAME = `${CACHE_PREFIX}${VERSION}`;
const APP_SHELL = [
  './index.html',
  './styles.css',
  './app.js',
  './data.js',
  './manifest.webmanifest',
  './preview.html',
  './preview.js',
  './preview.css',
  './assets/logo.png',
  './assets/food-sheet.png',
  './assets/avatar.png',
  './assets/map.png',
  './assets/icon-192.png',
  './assets/icon-512.png',
  ...[
    'arrow-left', 'arrow-right', 'bell', 'camera', 'check', 'chevron-right',
    'circle', 'current-location', 'heart', 'home', 'map', 'map-pin', 'minus',
    'plus', 'receipt', 'search', 'settings', 'star', 'user'
  ].map(name => `./assets/icons/${name}.svg`)
].map(path => new URL(path, SCOPE_URL).href);
const INDEX_URL = new URL('./index.html', SCOPE_URL).href;

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL)));
  // A replacement worker waits until the current app windows are closed.
  // This preserves an in-progress reservation during an update.
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(names => Promise.all(names
        .filter(name => name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME)
        .map(name => caches.delete(name))))
      .then(() => self.clients.claim())
  );
});

function mayCache(response) {
  return response && response.status === 200 && response.type === 'basic';
}

self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== SCOPE_URL.origin ||
      !url.pathname.startsWith(SCOPE_URL.pathname)) return;

  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE_NAME);
      try {
        const response = await fetch(request);
        if (mayCache(response) &&
            (url.pathname === SCOPE_URL.pathname || url.pathname === new URL(INDEX_URL).pathname)) {
          await cache.put(INDEX_URL, response.clone());
        }
        return response;
      } catch {
        return (await cache.match(request, { ignoreSearch: true })) ||
          (await cache.match(INDEX_URL)) || Response.error();
      }
    })());
    return;
  }

  const isStatic = ['script', 'style', 'image', 'font', 'manifest'].includes(request.destination) ||
    /\.(?:js|css|png|jpe?g|webp|svg|ico|woff2?|webmanifest)$/i.test(url.pathname);
  if (!isStatic) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request);
    if (cached) return cached;
    const response = await fetch(request);
    if (mayCache(response)) await cache.put(request, response.clone());
    return response;
  })());
});
