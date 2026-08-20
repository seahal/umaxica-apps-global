import { Controller } from "@hotwired/stimulus";

import { csrfToken } from "@/lib/csrf";
import { readBoolean } from "@/lib/payload";

export default class extends Controller {
  static override values = {
    settingsUrl: String,
  };

  // Stimulus defines this from `static values` at registration; the declarations record what it
  // creates so the compiler sees the same properties the runtime does.
  declare readonly settingsUrlValue: string;
  declare readonly hasSettingsUrlValue: boolean;

  // Connects to data-controller="cookie-banner"
  override connect() {
    void this.checkConsentState();
  }

  async checkConsentState() {
    try {
      const consentState = await this.fetchCookieConsent();
      // `show_banner` is the field the endpoint answers with (`PreferenceWebCookieActions#show`).
      // Reading `consented` here - a key that response has never carried - is why a recorded
      // decision never suppressed the banner: the read silently found nothing and left it up on
      // every load. Only an explicit `false` removes it; anything else keeps the prompt, because
      // a consent prompt that fails to appear is the worse of the two failures.
      if (readBoolean(consentState, "show_banner") === false) {
        this.element.remove();
      }
    } catch {
      // Keep the banner visible when the verified preference JWT cannot be read.
    }
  }

  // Handle invisible/close action
  invisible(event: Event) {
    event.preventDefault();
    this.element.remove();
  }

  // Handle accept action
  accept(event: Event) {
    event.preventDefault();
    void this.submitConsent(true).catch((error) => this.dispatchConsentError(error));
  }

  // Handle reject action
  reject(event: Event) {
    event.preventDefault();
    void this.submitConsent(false).catch((error) => this.dispatchConsentError(error));
  }

  // Handle open settings action
  openSettings(event: Event) {
    event.preventDefault();
    if (this.hasSettingsUrlValue) {
      window.location.assign(this.settingsUrlValue);
      return;
    }
    this.dispatch("open-settings", { detail: { consent: null } });
  }

  // Fetch cookie consent from API endpoint
  async fetchCookieConsent(): Promise<unknown> {
    const response = await fetch(this.cookieEndpointUrl());
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const body: unknown = await response.json();
    return body;
  }

  async submitConsent(consented: boolean) {
    const cookie = this.cookieConsentAttrs(consented);
    const response = await fetch(this.cookieEndpointUrl(), {
      method: "PATCH",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({ cookie }),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    // `PreferenceWebCookieActions#update` answers 204 with no body, so parsing one threw here and
    // the banner was never removed: the visitor pressed a button, the decision was stored, and the
    // banner stayed. The decision just submitted is what the server stored, so it is what the
    // preference form is synced from.
    this.syncCookieFormConsent(cookie);
    this.element.remove();
  }

  cookieConsentAttrs(consented: boolean) {
    return {
      consented: true,
      functional: consented,
      performant: consented,
      targetable: consented,
    };
  }

  syncCookieFormConsent(consentState: unknown) {
    const form = document.querySelector("[data-controller~='cookie-toggle'] form");
    if (!form) {
      return;
    }

    ["consented", "functional", "performant", "targetable"].forEach((field) => {
      const value = readBoolean(consentState, field);
      if (value === undefined) {
        return;
      }
      const checkbox = form.querySelector<HTMLInputElement>(
        `input[type="checkbox"][name="preference_cookie[${field}]"]`,
      );
      if (checkbox) {
        checkbox.checked = value;
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
    return ["ri", "lx", "ct", "tz", "cu", "df", "tf", "mo", "dn", "ps"];
  }

  dispatchConsentError(error: unknown) {
    this.dispatch("error", {
      detail: {
        message: "Cookie consent update failed",
        error,
      },
    });
  }
}
