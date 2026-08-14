// Client-side theme application.
//
// Rails renders `data-theme` and the theme class on <html> from the `ct` cookie so the first paint
// already carries the visitor's theme. This module keeps that in sync afterwards: it applies a new
// choice immediately, follows the system setting while the choice is "system", and reconciles with
// the server, which is the authority for the stored preference.
//
// The wire format is the two-letter code the preference store uses; `Theme` is the name the UI
// works in. Converting at the boundary keeps the codes out of the components.

export type Theme = "dark" | "light" | "system";

const THEME_BY_CODE: Record<string, Theme> = {
  dr: "dark",
  dark: "dark",
  li: "light",
  light: "light",
  sy: "system",
  system: "system",
};

const CODE_BY_THEME: Record<Theme, string> = {
  dark: "dr",
  light: "li",
  system: "sy",
};

export function themeFromCode(value: string | null | undefined): Theme {
  return (value && THEME_BY_CODE[value.toLowerCase()]) || "system";
}

export function codeFromTheme(theme: Theme): string {
  return CODE_BY_THEME[theme];
}

export function readThemeCookie(): Theme {
  const cookie = document.cookie
    .split(";")
    .map((part) => part.trim().split("="))
    .find(([key]) => key === "ct");

  return themeFromCode(cookie?.[1] ? decodeURIComponent(cookie[1]) : null);
}

export function applyTheme(theme: Theme): void {
  const html = document.documentElement;
  const applied =
    theme === "system"
      ? window.matchMedia("(prefers-color-scheme: dark)").matches
        ? "dark"
        : "light"
      : theme;

  html.dataset.theme = theme;
  html.classList.remove("theme-dark", "theme-light", "theme-system");
  html.classList.add(`theme-${theme}`);
  html.classList.toggle("dark", applied === "dark");
}

/**
 * Keeps the document following the system setting. Returns a cleanup function so a React effect
 * can unsubscribe; the caller owns which theme is current.
 */
export function watchSystemTheme(currentTheme: () => Theme): () => void {
  const media = window.matchMedia("(prefers-color-scheme: dark)");
  const sync = () => applyTheme(currentTheme());

  media.addEventListener("change", sync);

  return () => media.removeEventListener("change", sync);
}

function themeEndpointUrl({ includeThemeParams = true }: { includeThemeParams?: boolean } = {}) {
  const endpoint = new URL("/web/v0/theme", window.location.origin);
  endpoint.search = window.location.search;
  if (!includeThemeParams) {
    endpoint.searchParams.delete("ct");
    endpoint.searchParams.delete("theme");
  }
  return endpoint.toString();
}

/** The stored preference, or null when it cannot be read; the cookie stays authoritative then. */
export async function fetchStoredTheme(): Promise<Theme | null> {
  try {
    const response = await fetch(themeEndpointUrl());
    if (!response.ok) {
      return null;
    }
    const data = (await response.json()) as { theme?: string };
    return themeFromCode(data.theme);
  } catch {
    return null;
  }
}

/** Persists a choice and returns what the server stored, falling back to the requested theme. */
export async function persistTheme(theme: Theme, csrf: string): Promise<Theme> {
  try {
    const response = await fetch(themeEndpointUrl({ includeThemeParams: false }), {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...(csrf ? { "X-CSRF-Token": csrf } : {}),
      },
      body: JSON.stringify({ theme }),
    });

    if (!response.ok) {
      return theme;
    }

    const data = (await response.json()) as { theme?: string };
    return data.theme ? themeFromCode(data.theme) : theme;
  } catch {
    return theme;
  }
}
