import { Controller } from "@hotwired/stimulus";
import { normalizePublicKeyOptions } from "controllers/webauthn_utils";

export default class extends Controller {
  static targets = ["challengeId", "credentialJson", "error", "status"];
  static values = { options: String, challengeId: String };

  async authenticate(event) {
    event.preventDefault();
    this.clearMessages();

    if (!window.PublicKeyCredential) {
      this.showError("このブラウザはPasskeyに対応していません");
      return;
    }

    if (!this.optionsValue || !this.challengeIdValue) {
      this.showError("認証オプションの取得に失敗しました");
      return;
    }

    try {
      this.showStatus("認証器でPasskeyを確認中...");
      const options = JSON.parse(this.optionsValue);
      const publicKey = normalizePublicKeyOptions(options);
      const credential = await navigator.credentials.get({ publicKey });

      this.credentialJsonTarget.value = JSON.stringify(this.encodeCredential(credential));
      this.challengeIdTarget.value = this.challengeIdValue;

      this.showStatus("サーバーで検証中...");
      this.element.closest("form").requestSubmit();
    } catch (error) {
      if (error.name === "NotAllowedError") {
        this.showError("認証がキャンセルされました");
      } else if (error.name === "SecurityError") {
        this.showError("セキュリティエラーが発生しました");
      } else {
        this.showError(error.message || "認証中にエラーが発生しました");
      }
    }
  }

  encodeCredential(credential) {
    const { response } = credential;

    return {
      id: credential.id,
      rawId: this.bufferToBase64url(credential.rawId),
      type: credential.type,
      authenticatorAttachment: credential.authenticatorAttachment || null,
      response: {
        clientDataJSON: this.bufferToBase64url(response.clientDataJSON),
        authenticatorData: this.bufferToBase64url(response.authenticatorData),
        signature: this.bufferToBase64url(response.signature),
        userHandle: response.userHandle ? this.bufferToBase64url(response.userHandle) : null,
      },
      clientExtensionResults: credential.getClientExtensionResults(),
    };
  }

  bufferToBase64url(buffer) {
    const bytes = new Uint8Array(buffer);
    let binary = "";
    for (let i = 0; i < bytes.length; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
  }

  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message;
      this.errorTarget.classList.remove("hidden");
    }
    if (this.hasStatusTarget) {
      this.statusTarget.classList.add("hidden");
    }
  }

  showStatus(message) {
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
