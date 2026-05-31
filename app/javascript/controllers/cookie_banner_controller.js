import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
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
      if (this.hasCookieConsent()) {
        this.element.remove();
      }
    }
  }

  normalizeConsentValue(value) {
    if (!value) {
      return null;
    }

    return value.toLowerCase();
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
    void this.dispatchSettingsEvent();
  }

  async dispatchSettingsEvent() {
    try {
      const consent = await this.fetchCookieConsent();
      this.dispatch("open-settings", { detail: { consent } });
    } catch {
      this.dispatch("open-settings", { detail: { consent: this.getCookieConsent() } });
    }
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
    const response = await fetch(this.cookieEndpointUrl(), {
      method: "PATCH",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken(),
      },
      body: JSON.stringify({ consented }),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    this.setCookieConsent(consented ? "accepted" : "rejected");
    this.element.remove();
  }

  cookieEndpointUrl() {
    const endpoint = new URL("/web/v0/cookie", window.location.origin);
    endpoint.search = window.location.search;
    return endpoint.toString();
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

  // Helper: Set cookie consent preference
  setCookieConsent(value) {
    const expires = new Date();
    expires.setFullYear(expires.getFullYear() + 1);
    document.cookie = `cookie_consent=${value}; expires=${expires.toUTCString()}; path=/`;
  }

  // Helper: Get current cookie consent value
  getCookieConsent() {
    const name = "cookie_consent=";
    const decodedCookie = decodeURIComponent(document.cookie);
    const cookies = decodedCookie.split(";");
    for (let cookie of cookies) {
      cookie = cookie.trim();
      if (cookie.indexOf(name) === 0) {
        return this.normalizeConsentValue(cookie.substring(name.length));
      }
    }
    return null;
  }

  // Helper: Check if user has already provided consent
  hasCookieConsent() {
    return this.getCookieConsent() !== null;
  }
}
