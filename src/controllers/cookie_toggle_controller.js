import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="cookie-toggle"
export default class extends Controller {
  static targets = ["checkbox", "status"];

  connect() {
    this.updateStatus();
    this.setupFormListener();
  }

  toggle(_event) {
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

  async onFormSubmitEnd(event) {
    if (event.detail.success) {
      try {
        const consentState = await this.fetchCookieConsent();
        if (consentState) {
          this.syncCheckboxesFromAPI(consentState);
          this.updateStatus();
        }
      } catch {
        this.updateStatus();
      }
    }
  }

  async fetchCookieConsent() {
    const response = await fetch(this.cookieEndpointUrl());
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return await response.json();
  }

  cookieEndpointUrl() {
    const endpoint = new URL("/web/v0/cookie", window.location.origin);
    endpoint.search = window.location.search;
    return endpoint.toString();
  }

  syncCheckboxesFromAPI(consentState) {
    const fieldMap = {
      functional: "functional",
      performant: "performant",
      targetable: "targetable",
      consented: "consented",
    };

    Object.entries(fieldMap).forEach(([apiKey, fieldName]) => {
      const checkbox = this.element.querySelector(`input[name="preference_cookie[${fieldName}]"]`);
      if (checkbox && apiKey in consentState) {
        checkbox.checked = consentState[apiKey];
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
