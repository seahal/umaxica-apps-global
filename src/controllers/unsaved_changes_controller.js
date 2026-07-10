import { Controller } from "@hotwired/stimulus";

// Warn before navigating away with unsaved form changes.
export default class extends Controller {
  static values = { message: String };

  connect() {
    this.dirty = false;

    this.element.addEventListener("input", this.handleInput);
    this.element.addEventListener("change", this.handleInput);
    this.element.addEventListener("submit", this.handleSubmit);
    document.addEventListener("turbo:before-visit", this.handleBeforeVisit);
    window.addEventListener("beforeunload", this.handleBeforeUnload);
  }

  disconnect() {
    this.element.removeEventListener("input", this.handleInput);
    this.element.removeEventListener("change", this.handleInput);
    this.element.removeEventListener("submit", this.handleSubmit);
    document.removeEventListener("turbo:before-visit", this.handleBeforeVisit);
    window.removeEventListener("beforeunload", this.handleBeforeUnload);
  }

  handleInput = () => {
    this.dirty = true;
  };

  handleSubmit = () => {
    this.dirty = false;
  };

  handleBeforeVisit = (event) => {
    if (!this.dirty) {
      return;
    }
    const message = this.messageValue || "変更は保存されていません。移動しますか？";
    // eslint-disable-next-line no-alert
    if (!window.confirm(message)) {
      event.preventDefault();
    }
  };

  handleBeforeUnload = (event) => {
    if (!this.dirty) {
      return;
    }
    const message = this.messageValue || "変更は保存されていません。移動しますか？";
    event.preventDefault();
    event.returnValue = message;
  };
}
