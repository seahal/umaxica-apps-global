import { Controller } from "@hotwired/stimulus";

import { solveInvisibleTurnstile } from "@/features/auth/passkeys/invisibleTurnstile";
import { getAssertion, passkeysSupported } from "@/features/auth/passkeys/webauthn";
import { readObject, readString } from "@/lib/payload";

import { CEREMONY_REDIRECTED, ceremonyErrorMessage, postCeremonyJson } from "./passkey_ceremony";

// Passkey Authentication Controller
// Handles WebAuthn credential assertion for passkey login.
//
// The ceremony itself lives in `@/features/auth/passkeys/*`, which the React passkey screens use as
// well; this controller is the form around it.
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
  static override targets = ["identifier", "error", "status", "turnstileResponse"];
  static override values = {
    optionsUrl: String,
    verificationUrl: String,
    region: String,
    identifierParam: { type: String, default: "email" },
    turnstileSiteKey: String,
    turnstileErrorMessage: {
      type: String,
      default: "Security verification failed. Please refresh and try again.",
    },
  };

  // Stimulus defines these from `static targets` and `static values` at registration; the
  // declarations record what it creates so the compiler sees the same properties the runtime does.
  declare readonly identifierTarget: HTMLInputElement;
  declare readonly hasIdentifierTarget: boolean;
  declare readonly errorTarget: HTMLElement;
  declare readonly hasErrorTarget: boolean;
  declare readonly statusTarget: HTMLElement;
  declare readonly hasStatusTarget: boolean;
  declare readonly turnstileResponseTarget: HTMLInputElement;
  declare readonly hasTurnstileResponseTarget: boolean;
  declare readonly optionsUrlValue: string;
  declare readonly verificationUrlValue: string;
  declare readonly regionValue: string;
  declare readonly hasRegionValue: boolean;
  declare readonly identifierParamValue: string;
  declare readonly turnstileSiteKeyValue: string;
  declare readonly turnstileErrorMessageValue: string;

  get identifierValue(): string {
    if (this.hasIdentifierTarget) {
      return this.identifierTarget.value.trim();
    }
    return "";
  }

  async authenticate(event: Event) {
    event.preventDefault();
    this.clearMessages();

    // Check WebAuthn support
    if (!passkeysSupported()) {
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
      const begun = await postCeremonyJson(
        this.optionsUrlValue,
        {
          [this.identifierParamValue]: identifier,
          "cf-turnstile-response": turnstileToken,
          ri: this.hasRegionValue ? this.regionValue : undefined,
        },
        "オプションの取得に失敗しました",
      );

      if (begun === CEREMONY_REDIRECTED) {
        return;
      }

      this.showStatus("認証器でPasskeyを確認中...");

      // Step 2: Get credential from authenticator
      const credential = await getAssertion(readObject(begun, "options"));

      this.showStatus("サーバーで検証中...");

      // Step 3: Send credential to server for verification
      const verified = await postCeremonyJson(
        this.verificationUrlValue,
        {
          challenge_id: readString(begun, "challenge_id"),
          credential,
          ri: this.hasRegionValue ? this.regionValue : undefined,
        },
        "認証に失敗しました",
      );

      if (verified === CEREMONY_REDIRECTED) {
        return;
      }

      // Step 4: Handle result
      this.followVerificationResult(verified);
    } catch (error) {
      this.showError(
        ceremonyErrorMessage(error, {
          NotAllowedError: "認証がキャンセルされました",
          SecurityError: "セキュリティエラーが発生しました",
          fallback: "認証中にエラーが発生しました",
        }),
      );
    }
  }

  private followVerificationResult(result: unknown): void {
    const status = readString(result, "status");
    const redirectUrl = readString(result, "redirect_url");

    if ((status !== "totp_required" && status !== "ok") || redirectUrl === undefined) {
      throw new Error("予期しない応答です");
    }

    this.showStatus(
      status === "totp_required" ? "二段階認証が必要です..." : "ログイン成功！リダイレクト中...",
    );
    window.location.href = redirectUrl;
  }

  async ensureTurnstileToken(): Promise<string> {
    if (this.hasTurnstileResponseTarget && this.turnstileResponseTarget.value) {
      return this.turnstileResponseTarget.value;
    }

    const token = await solveInvisibleTurnstile(
      this.turnstileSiteKeyValue,
      this.turnstileErrorMessageValue,
      this.element instanceof HTMLElement ? this.element : null,
    );

    if (this.hasTurnstileResponseTarget) {
      this.turnstileResponseTarget.value = token;
    }

    return token;
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
