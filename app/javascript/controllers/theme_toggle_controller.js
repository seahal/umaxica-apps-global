import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    current: String,
    endpoint: String,
  };

  connect() {
    this.currentTheme = this.currentValue || "sy";
  }

  toggle(event) {
    const theme = event.currentTarget.dataset.theme || event.currentTarget.value;
    if (!theme || theme === this.currentTheme) {
      return;
    }

    void this.updateTheme(theme);
  }

  async updateTheme(theme) {
    try {
      const response = await fetch(this.endpointValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        },
        body: JSON.stringify({
          preference_theme: { option_id: theme },
        }),
      });

      if (response.ok) {
        const body = await response.json();
        const appliedTheme = body.preference?.ct || theme;

        // Update cookie immediately for instant CSS feedback
        document.cookie = `ct=${appliedTheme}; path=/; max-age=31536000`;

        // Update current theme tracking
        this.currentTheme = appliedTheme;

        // Dispatch event for other components
        window.dispatchEvent(
          new CustomEvent("themeChanged", {
            detail: body.preference || { ct: appliedTheme },
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

  dispatchError(message, detail = {}) {
    this.dispatch("error", { detail: { message, ...detail } });
  }
}
