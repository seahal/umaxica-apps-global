import { Controller } from "@hotwired/stimulus";

const THEME_CODE_MAP = {
  dr: "dark",
  dark: "dark",
  li: "light",
  light: "light",
  sy: "system",
  system: "system",
};

function readCookie(name) {
  const cookie = document.cookie
    .split(";")
    .map((part) => part.trim().split("="))
    .find(([key]) => key === name);
  return cookie ? decodeURIComponent(cookie[1]) : null;
}

function resolveTheme(value) {
  if (!value) {
    return "system";
  }
  return THEME_CODE_MAP[value.toLowerCase()] || value.toLowerCase();
}

function applyTheme(theme) {
  const html = document.documentElement;
  const systemMatch = window.matchMedia("(prefers-color-scheme: dark)");
  const resolveSystem = () => (systemMatch.matches ? "dark" : "light");
  const appliedTheme = theme === "system" ? resolveSystem() : theme;
  html.dataset.theme = theme;
  html.classList.remove("theme-dark", "theme-light", "theme-system");
  html.classList.add(`theme-${theme}`);
  html.classList.toggle("dark", appliedTheme === "dark");

  if (theme === "system" && !html.dataset.systemListenerRegistered) {
    html.dataset.systemListenerRegistered = "true";
    systemMatch.addEventListener("change", () => {
      html.classList.toggle("dark", resolveSystem() === "dark");
    });
  }
}

function applyThemeFromCookie() {
  const raw = readCookie("ct");
  const theme = resolveTheme(raw);
  applyTheme(theme);

  const valueEl = document.querySelector("#js-theme-cookie-value");
  if (valueEl) {
    valueEl.textContent = theme;
  }
}

export default class extends Controller {
  connect() {
    void this.fetchAndSyncTheme();
  }

  select(event) {
    const { value } = event.target;
    const theme = { system: "system", dark: "dark", light: "light" }[value] ?? "system";
    const code = { system: "sy", dark: "dr", light: "li" }[theme];
    this.selectedThemeCode = code;
    this.syncRadioFromThemeCode(code);
    this.applyThemeFromCode(code);
    void this.persistTheme(theme);
  }

  async persistTheme(theme) {
    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
      const headers = {
        "Content-Type": "application/json",
        Accept: "application/json",
      };
      if (csrfToken) {
        headers["X-CSRF-Token"] = csrfToken;
      }

      const response = await fetch(this.themeEndpointUrl({ includeThemeParams: false }), {
        method: "PATCH",
        headers,
        body: JSON.stringify({ theme }),
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      const themeCode = data.theme || { system: "sy", dark: "dr", light: "li" }[theme] || "sy";
      this.syncRadioFromThemeCode(themeCode);
      this.applyThemeFromCode(themeCode);
    } catch {
      const code = { system: "sy", dark: "dr", light: "li" }[theme] || "sy";
      this.syncRadioFromThemeCode(code);
      this.applyThemeFromCode(code);
    }
  }

  async fetchAndSyncTheme() {
    try {
      const response = await fetch(this.themeEndpointUrl());
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const data = await response.json();
      const themeCode = data.theme || "sy";
      if (this.selectedThemeCode) {
        return;
      }
      this.syncRadioFromThemeCode(themeCode);
      this.applyThemeFromCode(themeCode);
    } catch {
      this.syncRadio();
      applyThemeFromCookie();
    }
  }

  themeEndpointUrl({ includeThemeParams = true } = {}) {
    const endpoint = new URL("/web/v0/theme", window.location.origin);
    endpoint.search = window.location.search;
    if (!includeThemeParams) {
      endpoint.searchParams.delete("ct");
      endpoint.searchParams.delete("theme");
    }
    return endpoint.toString();
  }

  syncRadio() {
    const raw = readCookie("ct");
    const map = { sy: "system", dr: "dark", li: "light" };
    const value = map[raw] ?? "system";
    const radio = this.element.querySelector(`input[value="${value}"]`);
    if (radio) {
      radio.checked = true;
    }
  }

  syncRadioFromThemeCode(themeCode) {
    const map = { sy: "system", dr: "dark", li: "light" };
    const value = map[themeCode] ?? "system";
    const radio = this.element.querySelector(`input[value="${value}"]`);
    if (radio) {
      radio.checked = true;
    }
  }

  applyThemeFromCode(themeCode) {
    const map = { sy: "system", dr: "dark", li: "light" };
    const theme = map[themeCode] ?? "system";
    applyTheme(theme);

    const valueEl = document.querySelector("#js-theme-cookie-value");
    if (valueEl) {
      valueEl.textContent = theme;
    }
  }
}
