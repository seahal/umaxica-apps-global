const TURNSTILE_API_SELECTOR = "script[src*='challenges.cloudflare.com/turnstile/v0/api.js']";
const DEFAULT_TIMEOUT_MS = 5000;

export function waitForTurnstileApi(errorMessage, timeoutMs = DEFAULT_TIMEOUT_MS) {
  if (window.turnstile) {
    return Promise.resolve(window.turnstile);
  }

  const script = document.querySelector(TURNSTILE_API_SELECTOR);
  if (!script) {
    return Promise.reject(new Error(errorMessage));
  }

  return new Promise((resolve, reject) => {
    const timeout = window.setTimeout(() => {
      cleanup();
      reject(new Error(errorMessage));
    }, timeoutMs);

    const cleanup = () => {
      window.clearTimeout(timeout);
      script.removeEventListener("load", handleLoad);
      script.removeEventListener("error", handleError);
    };

    const handleLoad = () => {
      cleanup();
      if (window.turnstile) {
        resolve(window.turnstile);
        return;
      }
      reject(new Error(errorMessage));
    };

    const handleError = () => {
      cleanup();
      reject(new Error(errorMessage));
    };

    script.addEventListener("load", handleLoad, { once: true });
    script.addEventListener("error", handleError, { once: true });
  });
}
