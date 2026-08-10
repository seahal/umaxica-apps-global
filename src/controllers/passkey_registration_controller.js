import { Controller } from "@hotwired/stimulus";

import { waitForTurnstileApi } from "./turnstile_api";
import { normalizePublicKeyOptions } from "./webauthn_utils";

// Passkey Registration Controller
// Handles WebAuthn credential creation for passkey registration.
//
// Usage:
//   <div data-controller="passkey-registration"
//        data-passkey-registration-options-url-value="/settings/passkeys/options"
//        data-passkey-registration-verification-url-value="/settings/passkeys/verification">
//     <input type="text" data-passkey-registration-target="description" placeholder="Passkey name">
//     <button data-action="click->passkey-registration#register">Register Passkey</button>
//     <p data-passkey-registration-target="error" class="hidden text-red-600"></p>
//     <p data-passkey-registration-target="status" class="hidden text-gray-600"></p>
//   </div>
export default class extends Controller {
  static targets = ["description", "error", "status", "turnstileResponse"];
  static values = {
    beginUrl: String,
    finishUrl: String,
    successRedirectUrl: String,
    optionsUrl: String,
    verificationUrl: String,
    checkpointVersion: String,
    turnstileSiteKey: String,
    turnstileErrorMessage: {
      type: String,
      default: "Security verification failed. Please refresh and try again.",
    },
  };

  get csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : "";
  }

  get descriptionValue() {
    if (this.hasDescriptionTarget) {
      return this.descriptionTarget.value || "";
    }
    return "";
  }

  get requestBeginUrl() {
    if (this.hasBeginUrlValue) {
      return this.beginUrlValue;
    }
    return this.optionsUrlValue;
  }

  get requestFinishUrl() {
    if (this.hasFinishUrlValue) {
      return this.finishUrlValue;
    }
    return this.verificationUrlValue;
  }

  get redirectUrl() {
    if (this.hasSuccessRedirectUrlValue) {
      return this.successRedirectUrlValue;
    }
    return "";
  }

  async register(event) {
    event.preventDefault();
    this.clearMessages();

    // Check WebAuthn support
    if (!window.PublicKeyCredential) {
      this.showError("このブラウザはPasskeyに対応していません");
      return;
    }

    try {
      const turnstileToken = await this.ensureTurnstileToken();
      this.showStatus("認証オプションを取得中...");

      // Step 1: Get registration options from server
      const optionsResponse = await fetch(this.requestBeginUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken,
        },
        body: JSON.stringify({
          "cf-turnstile-response": turnstileToken,
        }),
      });

      if (!optionsResponse.ok) {
        const contentType = optionsResponse.headers.get("content-type") || "";
        if (contentType.includes("application/json")) {
          const data = await optionsResponse.json();
          throw new Error(data.error || "オプションの取得に失敗しました");
        }
        if (optionsResponse.status === 401 || optionsResponse.status === 302) {
          window.location.reload();
          return;
        }
        throw new Error("オプションの取得に失敗しました");
      }

      const { challenge_id, options } = await optionsResponse.json();

      this.showStatus("認証器でPasskeyを作成中...");

      // Step 2: Create credential with authenticator
      const publicKeyOptions = normalizePublicKeyOptions(options);
      const credential = await navigator.credentials.create({ publicKey: publicKeyOptions });

      this.showStatus("サーバーで検証中...");

      // Step 3: Send credential to server for verification
      const verificationResponse = await fetch(this.requestFinishUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken,
        },
        body: JSON.stringify({
          challenge_id: challenge_id,
          credential: this.encodeCredential(credential),
          description: this.descriptionValue,
          checkpoint_version: this.hasCheckpointVersionValue
            ? this.checkpointVersionValue
            : undefined,
        }),
      });

      if (!verificationResponse.ok) {
        const contentType = verificationResponse.headers.get("content-type") || "";
        if (contentType.includes("application/json")) {
          const data = await verificationResponse.json();
          throw new Error(data.error || "登録に失敗しました");
        }
        if (verificationResponse.status === 401 || verificationResponse.status === 302) {
          window.location.reload();
          return;
        }
        throw new Error("登録に失敗しました");
      }

      const result = await verificationResponse.json();

      // Step 4: Success - redirect
      this.showStatus("登録完了！リダイレクト中...");
      if (result.redirect_url || this.redirectUrl) {
        window.location.href = result.redirect_url || this.redirectUrl;
      } else {
        window.location.reload();
      }
    } catch (error) {
      if (error.name === "NotAllowedError") {
        this.showError("認証がキャンセルされました");
      } else if (error.name === "InvalidStateError") {
        this.showError("このPasskeyは既に登録されています");
      } else {
        this.showError(error.message || "登録中にエラーが発生しました");
      }
    }
  }

  async ensureTurnstileToken() {
    if (!this.turnstileSiteKeyValue) {
      throw new Error(this.turnstileErrorMessageValue);
    }
    if (this.hasTurnstileResponseTarget && this.turnstileResponseTarget.value) {
      return this.turnstileResponseTarget.value;
    }

    await waitForTurnstileApi(this.turnstileErrorMessageValue);
    return this.requestTurnstileToken();
  }

  requestTurnstileToken() {
    return new Promise((resolve, reject) => {
      try {
        const container = document.createElement("div");
        container.style.display = "none";
        this.element.appendChild(container);

        window.turnstile.render(container, {
          sitekey: this.turnstileSiteKeyValue,
          size: "invisible",
          callback: (token) => {
            if (this.hasTurnstileResponseTarget) {
              this.turnstileResponseTarget.value = token;
            }
            resolve(token);
          },
          "error-callback": () => reject(new Error(this.turnstileErrorMessageValue)),
          "expired-callback": () => reject(new Error(this.turnstileErrorMessageValue)),
        });
      } catch (error) {
        // eslint-disable-next-line no-console
        console.error("Turnstile token request failed:", error);
        reject(new Error(this.turnstileErrorMessageValue));
      }
    });
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
        attestationObject: this.bufferToBase64url(response.attestationObject),
        transports: typeof response.getTransports === "function" ? response.getTransports() : [],
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
