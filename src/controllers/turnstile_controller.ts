import { Controller } from "@hotwired/stimulus";

import { type TurnstileApi, type TurnstileOptions, waitForTurnstileApi } from "@/lib/turnstile";

export default class extends Controller {
  static override targets = ["container", "response"];

  static override values = {
    action: String,
    cdata: String,
    mode: { type: String, default: "render" },
    errorMessage: {
      type: String,
      default: "Security verification failed. Please refresh and try again.",
    },
  };

  // Stimulus defines these from `static targets` and `static values` at registration; the
  // declarations record what it creates so the compiler sees the same properties the runtime does.
  declare readonly containerTarget: HTMLElement;
  declare readonly hasContainerTarget: boolean;
  declare readonly responseTarget: HTMLInputElement;
  declare readonly hasResponseTarget: boolean;
  declare readonly actionValue: string;
  declare readonly hasActionValue: boolean;
  declare readonly cdataValue: string;
  declare readonly hasCdataValue: boolean;
  declare readonly modeValue: string;
  declare readonly errorMessageValue: string;

  private completed = false;
  private form: HTMLFormElement | null = null;

  override connect() {
    this.completed = false;
    this.form = this.element.closest("form");
    if (this.form) {
      this.form.addEventListener("submit", this.preventDuplicateSubmit);
    }

    document.addEventListener("turbo:load", this.runScheduledChallenge, { once: true });

    /* v8 ignore next -- jsdom documents are already complete when controllers connect */
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", this.runScheduledChallenge, { once: true });
    } else {
      void this.scheduleChallenge().catch(this.reportScriptError);
    }
  }

  override disconnect() {
    if (this.form) {
      this.form.removeEventListener("submit", this.preventDuplicateSubmit);
    }
    document.removeEventListener("turbo:load", this.runScheduledChallenge);
    document.removeEventListener("DOMContentLoaded", this.runScheduledChallenge);
  }

  // The listener form: a DOM event handler cannot await, so the rejection is reported here
  // rather than becoming an unhandled one.
  runScheduledChallenge = () => {
    void this.scheduleChallenge().catch(this.reportScriptError);
  };

  scheduleChallenge = async () => {
    if (this.completed || !this.hasContainerTarget || !this.hasResponseTarget) {
      return;
    }

    let turnstile: TurnstileApi;
    try {
      turnstile = await waitForTurnstileApi(this.errorMessageValue);
    } catch (error) {
      this.reportScriptError(error);
      return;
    }

    // Built before the challenge is marked complete: a configuration this controller cannot honour
    // must not leave the widget in the "already challenged" state and silently skip the check.
    const options = this.challengeOptions();

    if (this.modeValue === "execute") {
      this.completed = true;
      const widgetId = turnstile.render(this.containerTarget, options);
      turnstile.execute(widgetId);
      return;
    }

    this.completed = true;
    turnstile.render(this.containerTarget, options);
  };

  challengeOptions(): TurnstileOptions {
    const options: TurnstileOptions = {
      // The site key is rendered onto the container by the layout; without it Turnstile has
      // nothing to challenge against, so an absent one is reported rather than sent as "undefined".
      sitekey: this.requiredSitekey(),
      callback: (token) => {
        this.responseTarget.value = token;
        this.dispatchTurnstileEvent("success");
      },
      "error-callback": (errorCode) => {
        this.responseTarget.value = "";
        // oxlint-disable-next-line no-console -- a refused challenge is only visible here.
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
        // oxlint-disable-next-line no-console -- a refused challenge is only visible here.
        console.error("Turnstile challenge timed out");
        this.dispatchTurnstileEvent("timeout");
      },
      "unsupported-callback": () => {
        this.responseTarget.value = "";
        // oxlint-disable-next-line no-console -- a refused challenge is only visible here.
        console.error("Turnstile client is unsupported");
        this.dispatchTurnstileEvent("unsupported");
      },
    };

    const action = this.hasActionValue ? this.actionValue : this.containerTarget.dataset["action"];
    if (action) {
      options.action = action;
    }

    const cData = this.hasCdataValue ? this.cdataValue : this.containerTarget.dataset["cdata"];
    if (cData) {
      options.cData = cData;
    }

    return options;
  }

  private requiredSitekey(): string {
    const { sitekey } = this.containerTarget.dataset;

    if (!sitekey) {
      throw new Error("The Turnstile container carries no data-sitekey.");
    }

    return sitekey;
  }

  dispatchTurnstileEvent(name: string, detail: Record<string, unknown> = {}) {
    window.dispatchEvent(
      new CustomEvent(`turnstile:${name}`, {
        detail: { ...detail, widgetId: this.containerTarget.id },
      }),
    );
  }

  reportScriptError = (error: unknown) => {
    // oxlint-disable-next-line no-console -- a missing challenge script is only visible here.
    console.error("Turnstile script failed to load:", error);
  };

  preventDuplicateSubmit = (event: Event) => {
    if (!this.form || !this.hasResponseTarget || !this.responseTarget.value) {
      return;
    }

    if (this.form.dataset["turnstileSubmitted"] === "true") {
      event.preventDefault();
      return;
    }

    this.form.dataset["turnstileSubmitted"] = "true";
    this.form
      .querySelectorAll<HTMLButtonElement | HTMLInputElement>("button, input[type='submit']")
      .forEach((submitter) => {
        submitter.disabled = true;
      });
  };
}
