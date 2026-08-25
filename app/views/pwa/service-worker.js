// Offline fallback service worker, rendered by Rails::PwaController.
//
// The install and fetch handlers below are the recipe Rails' own application generator ships in
// this file (commented out); they are enabled here unchanged. See
// adr/pwa-offline-route-exception.md.
//
// The worker performs no runtime caching, so no authenticated HTML, page props, JSON, CSRF token,
// or Set-Cookie response can ever enter the cache. The only cached entry is /offline, added at
// install time. A regression test pins that absence.

// Cache the offline fallback page on install:

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open("offline").then((cache) => cache.add("/offline")));
  self.skipWaiting();
});

// Serve the offline fallback page when a navigation request fails:

self.addEventListener("fetch", (event) => {
  if (event.request.mode === "navigate") {
    event.respondWith(fetch(event.request).catch(() => caches.match("/offline")));
  }
});
