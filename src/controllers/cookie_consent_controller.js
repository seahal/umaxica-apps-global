import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["banner"];
  static values = {
    consented: Boolean,
    endpoint: String,
  };

  connect() {
    // Show banner if not consented
    if (!this.consentedValue && this.hasBannerTarget) {
      this.showBanner();
    }
  }

  showBanner() {
    this.bannerTarget.classList.remove("hidden");
  }

  hideBanner() {
    this.bannerTarget.classList.add("hidden");
  }

  async accept(event) {
    event.preventDefault();
    await this.submitConsent(true);
  }

  async reject(event) {
    event.preventDefault();
    await this.submitConsent(false);
  }

  async submitConsent(accepted) {
    try {
      const response = await fetch(this.endpointValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        },
        body: JSON.stringify({
          preference_cookie: {
            consented: accepted,
            functional: accepted,
            performant: accepted,
            targetable: false,
          },
        }),
      });

      if (response.ok) {
        const body = await response.json();
        const consented = Boolean(body.preference?.consented ?? accepted);

        // Hide banner
        this.hideBanner();

        // Dispatch event
        window.dispatchEvent(
          new CustomEvent("consentChanged", {
            detail: body.preference || { consented },
          }),
        );
      } else {
        this.dispatchError("Consent update failed", { status: response.status });
      }
    } catch (error) {
      this.dispatchError("Consent update error", { error });
    }
  }

  dispatchError(message, detail = {}) {
    this.dispatch("error", { detail: { message, ...detail } });
  }
}
