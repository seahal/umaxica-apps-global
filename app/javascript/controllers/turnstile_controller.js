import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["container", "response"];

  static values = {
    mode: { type: String, default: "render" },
  };

  connect() {
    this.completed = false;

    this.apiScript = document.querySelector(
      "script[src*='challenges.cloudflare.com/turnstile/v0/api.js']",
    );
    if (this.apiScript) {
      this.apiScript.addEventListener("load", this.scheduleChallenge, { once: true });
      this.apiScript.addEventListener("error", this.reportScriptError, { once: true });
    }

    document.addEventListener("turbo:load", this.scheduleChallenge, { once: true });

    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", this.scheduleChallenge, { once: true });
    } else {
      this.scheduleChallenge();
    }
  }

  disconnect() {
    if (this.apiScript) {
      this.apiScript.removeEventListener("load", this.scheduleChallenge);
      this.apiScript.removeEventListener("error", this.reportScriptError);
    }
    document.removeEventListener("turbo:load", this.scheduleChallenge);
    document.removeEventListener("DOMContentLoaded", this.scheduleChallenge);
  }

  scheduleChallenge = () => {
    if (
      this.completed ||
      !window.turnstile ||
      !this.hasContainerTarget ||
      !this.hasResponseTarget
    ) {
      return;
    }

    if (this.modeValue === "execute") {
      this.completed = true;
      const widgetId = window.turnstile.render(this.containerTarget, this.challengeOptions());
      window.turnstile.execute(widgetId);
      return;
    }

    this.completed = true;
    window.turnstile.render(this.containerTarget, this.challengeOptions());
  };

  challengeOptions() {
    return {
      sitekey: this.containerTarget.dataset.sitekey,
      callback: (token) => {
        this.responseTarget.value = token;
        this.dispatchTurnstileEvent("success");
      },
      "error-callback": (errorCode) => {
        this.responseTarget.value = "";
        // eslint-disable-next-line no-console
        console.error("Turnstile error occurred:", errorCode);
        this.dispatchTurnstileEvent("error", { errorCode });
        return true;
      },
      "expired-callback": () => {
        this.responseTarget.value = "";
        this.dispatchTurnstileEvent("expired");
      },
      "timeout-callback": () => {
        this.responseTarget.value = "";
        // eslint-disable-next-line no-console
        console.error("Turnstile challenge timed out");
        this.dispatchTurnstileEvent("timeout");
      },
      "unsupported-callback": () => {
        this.responseTarget.value = "";
        // eslint-disable-next-line no-console
        console.error("Turnstile client is unsupported");
        this.dispatchTurnstileEvent("unsupported");
      },
    };
  }

  dispatchTurnstileEvent(name, detail = {}) {
    window.dispatchEvent(
      new CustomEvent(`turnstile:${name}`, {
        detail: { ...detail, widgetId: this.containerTarget.id },
      }),
    );
  }

  reportScriptError = () => {
    // eslint-disable-next-line no-console
    console.error("Turnstile script failed to load");
  };
}
