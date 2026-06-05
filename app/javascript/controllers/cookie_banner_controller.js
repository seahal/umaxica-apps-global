import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    settingsUrl: String,
  };

  // Connects to data-controller="cookie-banner"
  connect() {
    void this.checkConsentState();
  }

  async checkConsentState() {
    try {
      const consentState = await this.fetchCookieConsent();
      if (consentState && consentState.consented) {
        this.element.remove();
      }
    } catch {
      // Keep the banner visible when the verified preference JWT cannot be read.
    }
  }

  // Handle invisible/close action
  invisible(event) {
    event.preventDefault();
    this.element.remove();
  }

  // Handle accept action
  accept(event) {
    event.preventDefault();
    void this.submitConsent(true).catch((error) => this.dispatchConsentError(error));
  }

  // Handle reject action
  reject(event) {
    event.preventDefault();
    void this.submitConsent(false).catch((error) => this.dispatchConsentError(error));
  }

  // Handle open settings action
  openSettings(event) {
    event.preventDefault();
    if (this.hasSettingsUrlValue) {
      window.location.assign(this.settingsUrlValue);
      return;
    }
    this.dispatch("open-settings", { detail: { consent: null } });
  }

  // Fetch cookie consent from API endpoint
  async fetchCookieConsent() {
    const response = await fetch(this.cookieEndpointUrl());
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return await response.json();
  }

  async submitConsent(consented) {
    const cookie = this.cookieConsentAttrs(consented);
    const response = await fetch(this.cookieEndpointUrl(), {
      method: "PATCH",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken(),
      },
      body: JSON.stringify({ cookie }),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    this.syncCookieFormConsent(await response.json());
    this.element.remove();
  }

  cookieConsentAttrs(consented) {
    return {
      consented: true,
      functional: consented,
      performant: consented,
      targetable: consented,
    };
  }

  syncCookieFormConsent(consentState) {
    const form = document.querySelector("[data-controller~='cookie-toggle'] form");
    if (!form) {
      return;
    }

    ["consented", "functional", "performant", "targetable"].forEach((field) => {
      if (!(field in consentState)) {
        return;
      }
      const checkbox = form.querySelector(
        `input[type="checkbox"][name="preference_cookie[${field}]"]`,
      );
      if (checkbox) {
        checkbox.checked = Boolean(consentState[field]);
        checkbox.dispatchEvent(new Event("change", { bubbles: true }));
      }
    });
  }

  cookieEndpointUrl() {
    const endpoint = new URL("/web/v0/cookie", window.location.origin);
    this.cookieEndpointQueryKeys().forEach((key) => {
      const value = new URLSearchParams(window.location.search).get(key);
      if (value) {
        endpoint.searchParams.set(key, value);
      }
    });
    return endpoint.toString();
  }

  cookieEndpointQueryKeys() {
    return ["ri", "lx", "ct", "tz", "cu", "df", "tf", "mo", "dn", "ps", "r18s"];
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || "";
  }

  dispatchConsentError(error) {
    this.dispatch("error", {
      detail: {
        message: "Cookie consent update failed",
        error,
      },
    });
  }
}
