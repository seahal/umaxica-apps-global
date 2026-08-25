import { Controller } from "@hotwired/stimulus";

import { getAssertion, passkeysSupported } from "@/features/auth/passkeys/webauthn";

// The step-up passkey assertion, for the surfaces that do not boot React.
//
// The ceremony itself -- normalising the server's options, calling the credential API and encoding
// the assertion the way the server expects -- lives in `@/features/auth/passkeys/webauthn`, which
// the React passkey screens use as well. This controller is only the form: it runs the ceremony,
// fills the hidden fields and submits.
export default class extends Controller {
  static override targets = ["challengeId", "credentialJson", "error", "status"];
  static override values = { options: String, challengeId: String };

  // Stimulus defines these from `static targets` and `static values` at registration; the
  // declarations record what it creates so the compiler sees the same properties the runtime does.
  declare readonly challengeIdTarget: HTMLInputElement;
  declare readonly credentialJsonTarget: HTMLInputElement;
  declare readonly errorTarget: HTMLElement;
  declare readonly hasErrorTarget: boolean;
  declare readonly statusTarget: HTMLElement;
  declare readonly hasStatusTarget: boolean;
  declare readonly optionsValue: string;
  declare readonly challengeIdValue: string;

  async authenticate(event: Event) {
    event.preventDefault();
    this.clearMessages();

    if (!passkeysSupported()) {
      this.showError("このブラウザはPasskeyに対応していません");
      return;
    }

    if (!this.optionsValue || !this.challengeIdValue) {
      this.showError("認証オプションの取得に失敗しました");
      return;
    }

    const form = this.element.closest("form");

    if (!form) {
      this.showError("認証中にエラーが発生しました");
      return;
    }

    try {
      this.showStatus("認証器でPasskeyを確認中...");
      const options: unknown = JSON.parse(this.optionsValue);

      this.credentialJsonTarget.value = JSON.stringify(await getAssertion(options));
      this.challengeIdTarget.value = this.challengeIdValue;

      this.showStatus("サーバーで検証中...");
      form.requestSubmit();
    } catch (error) {
      this.showError(this.assertionErrorMessage(error));
    }
  }

  private assertionErrorMessage(error: unknown): string {
    if (error instanceof Error) {
      if (error.name === "NotAllowedError") {
        return "認証がキャンセルされました";
      }
      if (error.name === "SecurityError") {
        return "セキュリティエラーが発生しました";
      }
      if (error.message) {
        return error.message;
      }
    }

    return "認証中にエラーが発生しました";
  }

  showError(message: string) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message;
      this.errorTarget.classList.remove("hidden");
    }
    if (this.hasStatusTarget) {
      this.statusTarget.classList.add("hidden");
    }
  }

  showStatus(message: string) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message;
      this.statusTarget.classList.remove("hidden");
    }
  }

  clearMessages() {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = "";
      this.errorTarget.classList.add("hidden");
    }
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = "";
      this.statusTarget.classList.add("hidden");
    }
  }
}
