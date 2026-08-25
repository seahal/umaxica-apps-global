import { Controller } from "@hotwired/stimulus";

import { csrfToken } from "@/lib/csrf";
import { readBoolean, readObject } from "@/lib/payload";

export default class extends Controller {
  static override targets = ["banner"];
  static override values = {
    consented: Boolean,
    endpoint: String,
  };

  // Stimulus defines these from `static targets` and `static values` at registration; the
  // declarations record what it creates so the compiler sees the same properties the runtime does.
  declare readonly bannerTarget: HTMLElement;
  declare readonly hasBannerTarget: boolean;
  declare readonly consentedValue: boolean;
  declare readonly endpointValue: string;

  override connect() {
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

  async accept(event: Event) {
    event.preventDefault();
    await this.submitConsent(true);
  }

  async reject(event: Event) {
    event.preventDefault();
    await this.submitConsent(false);
  }

  async submitConsent(accepted: boolean) {
    try {
      const response = await fetch(this.endpointValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": csrfToken(),
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
        const body: unknown = await response.json();
        const preference = readObject(body, "preference");
        const consented = readBoolean(preference, "consented") ?? accepted;

        // Hide banner
        this.hideBanner();

        // Dispatch event
        window.dispatchEvent(
          new CustomEvent("consentChanged", {
            detail: preference ?? { consented },
          }),
        );
      } else {
        this.dispatchError("Consent update failed", { status: response.status });
      }
    } catch (error) {
      this.dispatchError("Consent update error", { error });
    }
  }

  dispatchError(message: string, detail: Record<string, unknown> = {}) {
    this.dispatch("error", { detail: { message, ...detail } });
  }
}
