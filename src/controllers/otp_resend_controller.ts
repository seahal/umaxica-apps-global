import { Controller } from "@hotwired/stimulus";

import { csrfToken } from "@/lib/csrf";
import { readBoolean, readNumber } from "@/lib/payload";

export default class extends Controller {
  static override targets = ["button", "input", "status"];

  static override values = {
    endpoint: String,
    state: String,
    buttonLabel: String,
    sentMessage: String,
    tooSoonMessage: String,
    failedMessage: String,
  };

  // Stimulus defines these from `static targets` and `static values` at registration; the
  // declarations record what it creates so the compiler sees the same properties the runtime does.
  declare readonly buttonTarget: HTMLButtonElement;
  declare readonly inputTarget: HTMLInputElement;
  declare readonly hasInputTarget: boolean;
  declare readonly statusTarget: HTMLElement;
  declare readonly endpointValue: string;
  declare readonly stateValue: string;
  declare readonly buttonLabelValue: string;
  declare readonly sentMessageValue: string;
  declare readonly tooSoonMessageValue: string;
  declare readonly failedMessageValue: string;

  private remainingSeconds = 0;
  private countdownTimer: ReturnType<typeof setInterval> | null = null;

  override connect() {
    this.remainingSeconds = 0;
    this.countdownTimer = null;
  }

  override disconnect() {
    this.stopCountdown();
  }

  async resend(event: Event) {
    event.preventDefault();
    if (this.remainingSeconds > 0) {
      return;
    }

    try {
      const response = await fetch(this.endpointValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": csrfToken(),
        },
        body: JSON.stringify({ state: this.stateValue }),
      });

      const payload: unknown = await response.json();

      if (response.status === 200 && readBoolean(payload, "resendable") === true) {
        this.clearOtpInput();
        this.statusTarget.textContent = this.sentMessageValue;
        this.resetButton();
        return;
      }

      if (response.status === 429) {
        const retryAfter = readNumber(payload, "retry_after") ?? 0;
        this.statusTarget.textContent = this.tooSoonMessageValue;
        this.startCountdown(retryAfter);
        return;
      }

      this.statusTarget.textContent = this.failedMessageValue;
    } catch {
      this.statusTarget.textContent = this.failedMessageValue;
    }
  }

  clearOtpInput() {
    if (this.hasInputTarget) {
      this.inputTarget.value = "";
      this.inputTarget.focus();
    }
  }

  startCountdown(seconds: number) {
    this.stopCountdown();
    this.remainingSeconds = Math.max(Math.ceil(seconds), 0);
    this.renderButton();

    if (this.remainingSeconds <= 0) {
      this.resetButton();
      return;
    }

    this.countdownTimer = setInterval(() => {
      this.remainingSeconds -= 1;
      if (this.remainingSeconds <= 0) {
        this.resetButton();
        return;
      }
      this.renderButton();
    }, 1000);
  }

  stopCountdown() {
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = null;
    }
  }

  renderButton() {
    this.buttonTarget.disabled = this.remainingSeconds > 0;
    if (this.remainingSeconds > 0) {
      this.buttonTarget.textContent = `${this.tooSoonMessageValue} (${this.remainingSeconds}s)`;
    } else {
      this.buttonTarget.textContent = this.buttonLabelValue;
    }
  }

  resetButton() {
    this.stopCountdown();
    this.remainingSeconds = 0;
    this.buttonTarget.disabled = false;
    this.buttonTarget.textContent = this.buttonLabelValue;
  }
}
