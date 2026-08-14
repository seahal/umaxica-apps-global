import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import {
  applyTheme,
  codeFromTheme,
  fetchStoredTheme,
  persistTheme,
  readThemeCookie,
  themeFromCode,
  watchSystemTheme,
} from "@/lib/theme";

type MediaListener = () => void;

let mediaMatches: boolean;
let listeners: MediaListener[];
let removed: MediaListener[];

function stubMatchMedia() {
  mediaMatches = false;
  listeners = [];
  removed = [];

  vi.stubGlobal(
    "matchMedia",
    vi.fn((query: string) => ({
      media: query,
      get matches() {
        return mediaMatches;
      },
      addEventListener: (_event: string, listener: MediaListener) => listeners.push(listener),
      removeEventListener: (_event: string, listener: MediaListener) => removed.push(listener),
    })),
  );
}

function clearCookies() {
  for (const part of document.cookie.split(";")) {
    const key = part.trim().split("=")[0];
    if (key) {
      document.cookie = `${key}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/`;
    }
  }
}

beforeEach(() => {
  stubMatchMedia();
  clearCookies();
  document.documentElement.className = "";
  delete document.documentElement.dataset.theme;
  window.history.replaceState({}, "", "/");
});

afterEach(() => {
  vi.unstubAllGlobals();
  clearCookies();
});

describe("themeFromCode", () => {
  test.each([
    ["dr", "dark"],
    ["dark", "dark"],
    ["li", "light"],
    ["light", "light"],
    ["sy", "system"],
    ["system", "system"],
    ["DR", "dark"],
  ])("maps the stored code %s to %s", (code, theme) => {
    expect(themeFromCode(code)).toBe(theme);
  });

  test.each([[null], [undefined], [""], ["nonsense"]])(
    "falls back to system for %s",
    (value: string | null | undefined) => {
      expect(themeFromCode(value)).toBe("system");
    },
  );
});

describe("codeFromTheme", () => {
  test.each([
    ["dark", "dr"],
    ["light", "li"],
    ["system", "sy"],
  ] as const)("maps %s to the wire code %s", (theme, code) => {
    expect(codeFromTheme(theme)).toBe(code);
  });
});

describe("readThemeCookie", () => {
  test("reads the theme Rails rendered the first paint from", () => {
    document.cookie = "ct=dr; path=/";

    expect(readThemeCookie()).toBe("dark");
  });

  test("reads ct even when other cookies are present", () => {
    document.cookie = "lx=en; path=/";
    document.cookie = "ct=li; path=/";
    document.cookie = "tz=asia%2Ftokyo; path=/";

    expect(readThemeCookie()).toBe("light");
  });

  test("decodes a percent encoded value", () => {
    document.cookie = `ct=${encodeURIComponent("system")}; path=/`;

    expect(readThemeCookie()).toBe("system");
  });

  test("falls back to system without a ct cookie", () => {
    document.cookie = "lx=en; path=/";

    expect(readThemeCookie()).toBe("system");
  });

  test("falls back to system when ct carries no value", () => {
    document.cookie = "ct=; path=/";

    expect(readThemeCookie()).toBe("system");
  });
});

describe("applyTheme", () => {
  test("marks the document dark for an explicit dark choice", () => {
    applyTheme("dark");

    expect(document.documentElement.dataset.theme).toBe("dark");
    expect(document.documentElement.classList.contains("theme-dark")).toBe(true);
    expect(document.documentElement.classList.contains("dark")).toBe(true);
  });

  test("marks the document light for an explicit light choice", () => {
    applyTheme("light");

    expect(document.documentElement.dataset.theme).toBe("light");
    expect(document.documentElement.classList.contains("theme-light")).toBe(true);
    expect(document.documentElement.classList.contains("dark")).toBe(false);
  });

  test("resolves the system choice against the system setting", () => {
    mediaMatches = true;
    applyTheme("system");

    expect(document.documentElement.dataset.theme).toBe("system");
    expect(document.documentElement.classList.contains("theme-system")).toBe(true);
    expect(document.documentElement.classList.contains("dark")).toBe(true);

    mediaMatches = false;
    applyTheme("system");

    expect(document.documentElement.classList.contains("dark")).toBe(false);
  });

  test("replaces the class of the previously applied theme", () => {
    applyTheme("dark");
    applyTheme("light");

    expect(document.documentElement.classList.contains("theme-dark")).toBe(false);
    expect(document.documentElement.classList.contains("theme-light")).toBe(true);
  });
});

describe("watchSystemTheme", () => {
  test("reapplies the caller's current theme when the system setting changes", () => {
    let current: "dark" | "light" | "system" = "system";
    const stop = watchSystemTheme(() => current);

    mediaMatches = true;
    for (const listener of listeners) {
      listener();
    }
    expect(document.documentElement.classList.contains("dark")).toBe(true);

    // An explicit choice must survive a system change.
    current = "light";
    for (const listener of listeners) {
      listener();
    }
    expect(document.documentElement.classList.contains("dark")).toBe(false);

    stop();
    expect(removed).toEqual(listeners);
  });
});

describe("fetchStoredTheme", () => {
  test("reads the stored preference through the theme endpoint", async () => {
    window.history.replaceState({}, "", "/?ct=dr&ri=jp");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ theme: "dr" }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(fetchStoredTheme()).resolves.toBe("dark");
    expect(fetchMock).toHaveBeenCalledWith("http://localhost:3000/web/v0/theme?ct=dr&ri=jp");
  });

  test("falls back to system when the endpoint answers an unknown code", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({}) }),
    );

    await expect(fetchStoredTheme()).resolves.toBe("system");
  });

  test("returns null on an error response so the cookie stays authoritative", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 500 }));

    await expect(fetchStoredTheme()).resolves.toBeNull();
  });

  test("returns null when the request itself fails", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("offline")));

    await expect(fetchStoredTheme()).resolves.toBeNull();
  });
});

describe("persistTheme", () => {
  test("sends the choice with the CSRF token and returns what the server stored", async () => {
    // The theme being replaced must not be echoed back to the endpoint as a request parameter.
    window.history.replaceState({}, "", "/?ct=li&theme=light&ri=jp");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ theme: "dr" }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(persistTheme("dark", "csrf-token")).resolves.toBe("dark");
    expect(fetchMock).toHaveBeenCalledWith("http://localhost:3000/web/v0/theme?ri=jp", {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": "csrf-token",
      },
      body: JSON.stringify({ theme: "dark" }),
    });
  });

  test("omits the CSRF header when no token is available", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ theme: "li" }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(persistTheme("light", "")).resolves.toBe("light");
    expect(fetchMock.mock.calls[0][1].headers).not.toHaveProperty("X-CSRF-Token");
  });

  test("keeps the requested theme when the response carries no theme", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({}) }),
    );

    await expect(persistTheme("dark", "csrf-token")).resolves.toBe("dark");
  });

  test("keeps the requested theme when the endpoint rejects the write", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 422 }));

    await expect(persistTheme("system", "csrf-token")).resolves.toBe("system");
  });

  test("keeps the requested theme when the request itself fails", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("offline")));

    await expect(persistTheme("light", "csrf-token")).resolves.toBe("light");
  });
});
