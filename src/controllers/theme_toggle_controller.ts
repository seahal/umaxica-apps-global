import { Controller } from "@hotwired/stimulus";

import { csrfToken } from "@/lib/csrf";
import { readObject, readString } from "@/lib/payload";

export default class extends Controller {
  static override values = {
    current: String,
    endpoint: String,
  };

  // Stimulus defines these from `static values` at registration; the declarations record what it
  // creates so the compiler sees the same properties the runtime does.
  declare readonly currentValue: string;
  declare readonly endpointValue: string;

  /** The theme currently applied, so a repeat of the same choice makes no request. */
  currentTheme = "sy";

  override connect() {
    this.currentTheme = this.currentValue || "sy";
  }

  toggle(event: Event) {
    const { currentTarget } = event;

    if (!(currentTarget instanceof HTMLElement)) {
      return;
    }

    const theme =
      currentTarget.dataset["theme"] ??
      (currentTarget instanceof HTMLInputElement ? currentTarget.value : undefined);

    if (!theme || theme === this.currentTheme) {
      return;
    }

    void this.updateTheme(theme);
  }

  async updateTheme(theme: string) {
    try {
      const response = await fetch(this.endpointValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": csrfToken(),
        },
        body: JSON.stringify({
          preference_theme: { option_id: theme },
        }),
      });

      if (response.ok) {
        const body: unknown = await response.json();
        const preference = readObject(body, "preference");
        const appliedTheme = readString(preference, "ct") ?? theme;

        // Update current theme tracking
        this.currentTheme = appliedTheme;

        // Dispatch event for other components
        window.dispatchEvent(
          new CustomEvent("themeChanged", {
            detail: preference ?? { ct: appliedTheme },
          }),
        );

        // Reload not needed - CSS updates via cookie
      } else {
        this.dispatchError("Theme update failed", { status: response.status });
      }
    } catch (error) {
      this.dispatchError("Theme update error", { error });
    }
  }

  dispatchError(message: string, detail: Record<string, unknown> = {}) {
    this.dispatch("error", { detail: { message, ...detail } });
  }
}
