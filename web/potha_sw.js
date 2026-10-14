// Potha's service worker: after the first visit, the web app starts and opens books with
// no network (constitution II). tool/build_web.sh fills in VERSION and PRECACHE
// (tool/write_service_worker.dart); left unfilled (`flutter run`), it refuses to install.
//
// - Install: caches the whole build except CanvasKit, debug symbols and the dictionary,
//   revalidating each file so an older copy in the HTTP cache can't slip in.
// - Requests: answered from this version's cache, or from the network. The CanvasKit
//   variant the browser loads is cached on its first fetch; the page also reports the one
//   it loaded before the worker existed. The dictionary always goes to the network: the
//   app keeps it in IndexedDB.
// - Updates: a new build has a new VERSION, so the browser installs it alongside. It takes
//   over once every tab of the app is closed (no skipWaiting): a running app loads its
//   reader code later and must get the same build's copy.
'use strict';

const VERSION = '__POTHA_VERSION__';
const PRECACHE = '__POTHA_PRECACHE__';

const CACHE_PREFIX = 'potha-';
const CACHE = CACHE_PREFIX + VERSION;
const DICTIONARY = 'assets/assets/dictionary/en.sqlite.gz';
const RUNTIME_CACHED = 'canvaskit/';

const scope = self.registration.scope;
const at = (path) => new URL(path, scope).href;

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      if (!Array.isArray(PRECACHE)) throw new Error('potha_sw.js was not filled in by the build');
      const cache = await caches.open(CACHE);
      await cache.addAll(PRECACHE.map((path) => new Request(at(path), { cache: 'no-cache' })));
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const name of await caches.keys()) {
        if (name.startsWith(CACHE_PREFIX) && name !== CACHE) await caches.delete(name);
      }
      // On the first visit the page started before the worker: take it over, so the reader
      // code and PDFium it loads later come from the cache.
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || !request.url.startsWith(scope)) return;
  if (request.url === at(DICTIONARY)) return;
  event.respondWith(respond(request));
});

async function respond(request) {
  const cache = await caches.open(CACHE);
  // The app has one page; every navigation in scope gets it.
  const cached = await cache.match(request.mode === 'navigate' ? at('index.html') : request);
  if (cached) return cached;
  const response = await fetch(request);
  if (response.ok && request.url.startsWith(at(RUNTIME_CACHED))) {
    await keep(cache, request, response.clone());
  }
  return response;
}

async function keep(cache, request, response) {
  try {
    await cache.put(request, response);
  } catch (e) {
    console.warn('Potha: not cached', request.url, e);
  }
}

// From the page: CanvasKit files it loaded before this worker controlled it.
self.addEventListener('message', (event) => {
  const urls = event.data?.type === 'cache-loaded' ? event.data.urls : null;
  if (!Array.isArray(urls)) return;
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE);
      for (const url of urls) {
        if (typeof url !== 'string' || !url.startsWith(at(RUNTIME_CACHED))) continue;
        if (await cache.match(url)) continue;
        const response = await fetch(url).catch(() => null);
        if (response?.ok) await keep(cache, new Request(url), response);
      }
    })(),
  );
});
