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
    const code = { system: "sy", dark: "dr", light: "li" }[value] ?? "sy";
    const secure = location.protocol === "https:" ? "; secure" : "";
    document.cookie = `ct=${code}; path=/; max-age=31536000; samesite=lax${secure}`;
    applyThemeFromCookie();
  }

  async fetchAndSyncTheme() {
    try {
      const response = await fetch(this.themeEndpointUrl());
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const data = await response.json();
      const themeCode = data.theme || "sy";
      this.syncRadioFromThemeCode(themeCode);
      this.applyThemeFromCode(themeCode);
    } catch {
      this.syncRadio();
      applyThemeFromCookie();
    }
  }

  themeEndpointUrl() {
    const endpoint = new URL("/web/v0/theme", window.location.origin);
    endpoint.search = window.location.search;
    return endpoint.toString();
  }

  syncRadio() {
    const raw = document.cookie
      .split(";")
      .map((p) => p.trim().split("="))
      .find(([k]) => k === "ct")?.[1];
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
