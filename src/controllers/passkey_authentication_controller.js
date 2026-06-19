import { Controller } from "@hotwired/stimulus";

import { normalizePublicKeyOptions } from "./webauthn_utils";

// Passkey Authentication Controller
// Handles WebAuthn credential assertion for passkey login.
//
// Usage:
//   <div data-controller="passkey-authentication"
//        data-passkey-authentication-options-url-value="/in/passkeys/options"
//        data-passkey-authentication-verification-url-value="/in/passkeys/verification">
//     <input type="email" data-passkey-authentication-target="identifier" placeholder="Email">
//     <button data-action="click->passkey-authentication#authenticate">Sign in with Passkey</button>
//     <p data-passkey-authentication-target="error" class="hidden text-red-600"></p>
//     <p data-passkey-authentication-target="status" class="hidden text-gray-600"></p>
//   </div>
export default class extends Controller {
  static targets = ["identifier", "error", "status", "turnstileResponse"];
  static values = {
    optionsUrl: String,
    verificationUrl: String,
    identifierParam: { type: String, default: "email" },
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

  get identifierValue() {
    if (this.hasIdentifierTarget) {
      return this.identifierTarget.value.trim();
    }
    return "";
  }

  async authenticate(event) {
    event.preventDefault();
    this.clearMessages();

    // Check WebAuthn support
    if (!window.PublicKeyCredential) {
      this.showError("このブラウザはPasskeyに対応していません");
      return;
    }

    const identifier = this.identifierValue;
    if (!identifier) {
      this.showError("メールアドレスまたはIDを入力してください");
      return;
    }

    try {
      const turnstileToken = await this.ensureTurnstileToken();
      this.showStatus("認証オプションを取得中...");

      // Step 1: Get authentication options from server
      const optionsResponse = await fetch(this.optionsUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken,
        },
        body: JSON.stringify({
          [this.identifierParamValue]: identifier,
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

      this.showStatus("認証器でPasskeyを確認中...");

      // Step 2: Get credential from authenticator
      const publicKeyOptions = normalizePublicKeyOptions(options);
      const credential = await navigator.credentials.get({ publicKey: publicKeyOptions });

      this.showStatus("サーバーで検証中...");

      // Step 3: Send credential to server for verification
      const verificationResponse = await fetch(this.verificationUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken,
        },
        body: JSON.stringify({
          challenge_id: challenge_id,
          credential: this.encodeCredential(credential),
        }),
      });

      if (!verificationResponse.ok) {
        const contentType = verificationResponse.headers.get("content-type") || "";
        if (contentType.includes("application/json")) {
          const data = await verificationResponse.json();
          throw new Error(data.error || "認証に失敗しました");
        }
        if (verificationResponse.status === 401 || verificationResponse.status === 302) {
          window.location.reload();
          return;
        }
        throw new Error("認証に失敗しました");
      }

      const result = await verificationResponse.json();

      // Step 4: Handle result
      if (result.status === "totp_required") {
        this.showStatus("二段階認証が必要です...");
        window.location.href = result.redirect_url;
      } else if (result.status === "ok") {
        this.showStatus("ログイン成功！リダイレクト中...");
        window.location.href = result.redirect_url;
      } else {
        throw new Error("予期しない応答です");
      }
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

  async ensureTurnstileToken() {
    if (!this.turnstileSiteKeyValue) {
      throw new Error(this.turnstileErrorMessageValue);
    }
    if (this.hasTurnstileResponseTarget && this.turnstileResponseTarget.value) {
      return this.turnstileResponseTarget.value;
    }

    await this.ensureTurnstileScriptLoaded();
    return this.requestTurnstileToken();
  }

  ensureTurnstileScriptLoaded() {
    return new Promise((resolve, reject) => {
      if (window.turnstile) {
        resolve();
        return;
      }

      const existingScript = document.querySelector(
        "script[src*='challenges.cloudflare.com/turnstile']",
      );
      if (existingScript) {
        existingScript.addEventListener("load", () => resolve(), { once: true });
        existingScript.addEventListener(
          "error",
          () => reject(new Error(this.turnstileErrorMessageValue)),
          { once: true },
        );
        return;
      }

      const script = document.createElement("script");
      script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
      script.async = true;
      script.defer = true;
      script.onload = () => resolve();
      script.onerror = () => reject(new Error(this.turnstileErrorMessageValue));
      document.head.appendChild(script);
    });
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
      } catch {
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
