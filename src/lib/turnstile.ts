// Access to the Cloudflare Turnstile API script that the surface layout loads.
//
// The script is loaded async with `render=explicit`, so a widget that mounts before it has arrived
// has to wait for it rather than assume `window.turnstile` exists.

export type TurnstileOptions = {
  sitekey: string;
  action?: string;
  cData?: string;
  /** Only the invisible flow sets this; a rendered widget leaves it out. */
  size?: "invisible";
  callback: (token: string) => void;
  // A handler may answer whether Turnstile should retry, or answer nothing at all. Each callback
  // is optional because a caller only wires the outcomes it acts on.
  "error-callback"?: (errorCode: string) => boolean | void;
  "expired-callback"?: () => void;
  "timeout-callback"?: () => void;
  "unsupported-callback"?: () => void;
};

export type TurnstileApi = {
  render: (container: HTMLElement, options: TurnstileOptions) => string;
  execute: (widgetId: string) => void;
  remove: (widgetId: string) => void;
};

declare global {
  interface Window {
    turnstile?: TurnstileApi;
  }
}

const TURNSTILE_API_SELECTOR = "script[src*='challenges.cloudflare.com/turnstile/v0/api.js']";
const DEFAULT_TIMEOUT_MS = 5000;

/**
 * Resolves with the Turnstile API once its script has loaded, and rejects when the script is
 * absent, fails, or does not arrive in time. A rejection means the challenge cannot be presented,
 * which the caller must surface rather than treat as a passed challenge.
 */
export function waitForTurnstileApi(
  errorMessage: string,
  timeoutMs: number = DEFAULT_TIMEOUT_MS,
): Promise<TurnstileApi> {
  if (window.turnstile) {
    return Promise.resolve(window.turnstile);
  }

  const script = document.querySelector(TURNSTILE_API_SELECTOR);
  if (!script) {
    return Promise.reject(new Error(errorMessage));
  }

  return new Promise((resolve, reject) => {
    const cleanup = () => {
      window.clearTimeout(timeout);
      script.removeEventListener("load", handleLoad);
      script.removeEventListener("error", handleError);
    };

    const timeout = window.setTimeout(() => {
      cleanup();
      reject(new Error(errorMessage));
    }, timeoutMs);

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
