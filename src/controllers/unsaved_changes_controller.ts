import { Controller } from "@hotwired/stimulus";

// Warn before navigating away with unsaved form changes.
export default class extends Controller {
  static override values = { message: String };

  // Stimulus defines this from `static values` at registration; the declaration records what it
  // creates so the compiler sees the same property the runtime does.
  declare readonly messageValue: string;

  private dirty = false;

  override connect() {
    this.dirty = false;

    this.element.addEventListener("input", this.handleInput);
    this.element.addEventListener("change", this.handleInput);
    this.element.addEventListener("submit", this.handleSubmit);
    document.addEventListener("turbo:before-visit", this.handleBeforeVisit);
    window.addEventListener("beforeunload", this.handleBeforeUnload);
  }

  override disconnect() {
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

  handleBeforeVisit = (event: Event) => {
    if (!this.dirty) {
      return;
    }
    const message = this.messageValue || "変更は保存されていません。移動しますか？";
    // oxlint-disable-next-line no-alert -- a beforeunload guard has no other way to ask.
    if (!window.confirm(message)) {
      event.preventDefault();
    }
  };

  handleBeforeUnload = (event: BeforeUnloadEvent) => {
    if (!this.dirty) {
      return;
    }
    // `preventDefault` is the whole modern contract: browsers show their own copy and have ignored
    // `returnValue` for years, so setting it would only be a deprecated no-op.
    event.preventDefault();
  };
}
