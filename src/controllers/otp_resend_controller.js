import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button", "input", "status"];

  static values = {
    endpoint: String,
    state: String,
    buttonLabel: String,
    sentMessage: String,
    tooSoonMessage: String,
    failedMessage: String,
  };

  connect() {
    this.remainingSeconds = 0;
    this.countdownTimer = null;
  }

  disconnect() {
    this.stopCountdown();
  }

  async resend(event) {
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
          "X-CSRF-Token": this.csrfToken(),
        },
        body: JSON.stringify({ state: this.stateValue }),
      });

      const payload = await response.json();

      if (response.status === 200 && payload.resendable === true) {
        this.clearOtpInput();
        this.statusTarget.textContent = this.sentMessageValue;
        this.resetButton();
        return;
      }

      if (response.status === 429) {
        const retryAfter = Number(payload.retry_after || 0);
        this.statusTarget.textContent = this.tooSoonMessageValue;
        this.startCountdown(retryAfter);
        return;
      }

      this.statusTarget.textContent = this.failedMessageValue;
    } catch {
      this.statusTarget.textContent = this.failedMessageValue;
    }
  }

  csrfToken() {
    const element = document.querySelector("meta[name='csrf-token']");
    return element ? element.getAttribute("content") : "";
  }

  clearOtpInput() {
    if (this.hasInputTarget) {
      this.inputTarget.value = "";
      this.inputTarget.focus();
    }
  }

  startCountdown(seconds) {
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
