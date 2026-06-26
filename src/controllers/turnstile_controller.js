import { Controller } from "@hotwired/stimulus";

import { waitForTurnstileApi } from "./turnstile_api";

export default class extends Controller {
  static targets = ["container", "response"];

  static values = {
    action: String,
    cdata: String,
    mode: { type: String, default: "render" },
    errorMessage: {
      type: String,
      default: "Security verification failed. Please refresh and try again.",
    },
  };

  connect() {
    this.completed = false;
    this.form = this.element?.closest?.("form");
    if (this.form) {
      this.form.addEventListener("submit", this.preventDuplicateSubmit);
    }

    document.addEventListener("turbo:load", this.scheduleChallenge, { once: true });

    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", this.scheduleChallenge, { once: true });
    } else {
      void this.scheduleChallenge();
    }
  }

  disconnect() {
    if (this.form) {
      this.form.removeEventListener("submit", this.preventDuplicateSubmit);
    }
    document.removeEventListener("turbo:load", this.scheduleChallenge);
    document.removeEventListener("DOMContentLoaded", this.scheduleChallenge);
  }

  scheduleChallenge = async () => {
    if (this.completed || !this.hasContainerTarget || !this.hasResponseTarget) {
      return;
    }

    let turnstile;
    try {
      turnstile = await waitForTurnstileApi(this.errorMessageValue);
    } catch (error) {
      this.reportScriptError(error);
      return;
    }

    if (this.modeValue === "execute") {
      this.completed = true;
      const widgetId = turnstile.render(this.containerTarget, this.challengeOptions());
      turnstile.execute(widgetId);
      return;
    }

    this.completed = true;
    turnstile.render(this.containerTarget, this.challengeOptions());
  };

  challengeOptions() {
    const options = {
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

    if (this.hasActionValue) {
      options.action = this.actionValue;
    } else if (this.containerTarget.dataset.action) {
      options.action = this.containerTarget.dataset.action;
    }
    if (this.hasCdataValue) {
      options.cData = this.cdataValue;
    } else if (this.containerTarget.dataset.cdata) {
      options.cData = this.containerTarget.dataset.cdata;
    }

    return options;
  }

  dispatchTurnstileEvent(name, detail = {}) {
    window.dispatchEvent(
      new CustomEvent(`turnstile:${name}`, {
        detail: { ...detail, widgetId: this.containerTarget.id },
      }),
    );
  }

  reportScriptError = (error) => {
    // eslint-disable-next-line no-console
    console.error("Turnstile script failed to load:", error);
  };

  preventDuplicateSubmit = (event) => {
    if (!this.form || !this.hasResponseTarget || !this.responseTarget.value) {
      return;
    }

    if (this.form.dataset.turnstileSubmitted === "true") {
      event.preventDefault();
      return;
    }

    this.form.dataset.turnstileSubmitted = "true";
    this.form.querySelectorAll("button, input[type='submit']").forEach((submitter) => {
      submitter.disabled = true;
    });
  };
}
