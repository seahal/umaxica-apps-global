import { Controller } from "@hotwired/stimulus";

import { readBoolean } from "@/lib/payload";

// Connects to data-controller="cookie-toggle"
export default class extends Controller {
  static override targets = ["checkbox", "status"];

  // Stimulus defines these from `static targets` at registration; the declarations record what it
  // creates so the compiler sees the same properties the runtime does.
  declare readonly checkboxTargets: HTMLInputElement[];
  declare readonly statusTarget: HTMLElement;
  declare readonly hasStatusTarget: boolean;

  override connect() {
    this.updateStatus();
    this.setupFormListener();
  }

  toggle(_event: Event) {
    this.updateStatus();
  }

  setupFormListener() {
    const form = this.element.querySelector("form");
    if (form) {
      form.addEventListener("turbo:submit-end", (event) => {
        void this.onFormSubmitEnd(event);
      });
    }
  }

  async onFormSubmitEnd(event: Event) {
    if (!(event instanceof CustomEvent) || readBoolean(event.detail, "success") !== true) {
      return;
    }

    try {
      const consentState = await this.fetchCookieConsent();
      // A body that is not an object carries no consent to sync; the checkboxes stay as they are.
      if (typeof consentState === "object" && consentState !== null) {
        this.syncCheckboxesFromAPI(consentState);
        this.updateStatus();
      }
    } catch {
      this.updateStatus();
    }
  }

  async fetchCookieConsent(): Promise<unknown> {
    const response = await fetch(this.cookieEndpointUrl());
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const body: unknown = await response.json();
    return body;
  }

  cookieEndpointUrl() {
    const endpoint = new URL("/web/v0/cookie", window.location.origin);
    endpoint.search = window.location.search;
    return endpoint.toString();
  }

  syncCheckboxesFromAPI(consentState: unknown) {
    const fields = ["functional", "performant", "targetable", "consented"];

    fields.forEach((fieldName) => {
      const checkbox = this.element.querySelector<HTMLInputElement>(
        `input[name="preference_cookie[${fieldName}]"]`,
      );
      const value = readBoolean(consentState, fieldName);
      if (checkbox && value !== undefined) {
        checkbox.checked = value;
      }
    });
  }

  updateStatus() {
    if (this.hasStatusTarget) {
      const checkedCount = this.checkboxTargets.filter((cb) => cb.checked).length;
      const totalCount = this.checkboxTargets.length;
      this.statusTarget.textContent = `${checkedCount} / ${totalCount} cookies enabled`;
    }
  }
}
