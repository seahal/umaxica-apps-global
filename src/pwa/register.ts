// Registers the browser service worker that backs the offline fallback page.
//
// This is the browser Service Worker, not a Cloudflare Worker. Only the base and auth surfaces call
// this; those are the surfaces whose layouts load a Vite bundle and whose origins serve
// /service-worker, the route Rails' own PWA generator defines. See
// adr/pwa-offline-route-exception.md.

const SERVICE_WORKER_URL = "/service-worker";

// Root scope, because the worker has to fall back for navigations anywhere on the origin. The script
// already sits at the origin root, which is the default scope, so no Service-Worker-Allowed header is
// involved. The path has no .js suffix: scope follows the script's directory, not its extension.
const SERVICE_WORKER_SCOPE = "/";

// The registration goes stale after 24 hours, but until then the browser honours the script's
// Cache-Control from the HTTP cache. Bypassing that cache keeps a deployed update from being pinned
// behind a cached copy of the script.
const UPDATE_VIA_CACHE = "none" as const;

let inFlight: Promise<ServiceWorkerRegistration | null> | null = null;

async function install(): Promise<ServiceWorkerRegistration | null> {
  if (!("serviceWorker" in navigator)) {
    // A browser without service worker support keeps the native connection-error screen. That is a
    // capability gap, not a failure, so there is nothing to report.
    return null;
  }

  if (!window.isSecureContext) {
    // eslint-disable-next-line no-console
    console.error(
      `Offline service worker not registered: ${window.location.origin} is not a secure context. ` +
        "Service workers require HTTPS or a localhost origin.",
    );
    return null;
  }

  try {
    return await navigator.serviceWorker.register(SERVICE_WORKER_URL, {
      scope: SERVICE_WORKER_SCOPE,
      updateViaCache: UPDATE_VIA_CACHE,
    });
  } catch (error) {
    // Reported rather than swallowed, and deliberately not rethrown: a failed offline fallback must
    // not take down the page that asked for it.
    // eslint-disable-next-line no-console
    console.error(`Offline service worker registration failed for ${SERVICE_WORKER_URL}:`, error);
    return null;
  }
}

/**
 * Registers the offline fallback service worker for the current origin.
 *
 * Safe to call more than once per document: the first call owns the registration and later calls
 * return the same promise. Resolves to `null` when the browser cannot register one.
 */
export function registerOfflineServiceWorker(): Promise<ServiceWorkerRegistration | null> {
  inFlight ??= install();

  return inFlight;
}
