import { Controller } from "@hotwired/stimulus";

import { solveInvisibleTurnstile } from "@/features/auth/passkeys/invisibleTurnstile";
import { createCredential, passkeysSupported } from "@/features/auth/passkeys/webauthn";
import { readNonEmptyString, readObject, readString } from "@/lib/payload";

import { CEREMONY_REDIRECTED, ceremonyErrorMessage, postCeremonyJson } from "./passkey_ceremony";

// Passkey Registration Controller
// Handles WebAuthn credential creation for passkey registration.
//
// The ceremony itself lives in `@/features/auth/passkeys/*`, which the React passkey screens use as
// well; this controller is the form around it.
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
  static override targets = ["description", "error", "status", "turnstileResponse"];
  static override values = {
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

  // Stimulus defines these from `static targets` and `static values` at registration; the
  // declarations record what it creates so the compiler sees the same properties the runtime does.
  declare readonly descriptionTarget: HTMLInputElement;
  declare readonly hasDescriptionTarget: boolean;
  declare readonly errorTarget: HTMLElement;
  declare readonly hasErrorTarget: boolean;
  declare readonly statusTarget: HTMLElement;
  declare readonly hasStatusTarget: boolean;
  declare readonly turnstileResponseTarget: HTMLInputElement;
  declare readonly hasTurnstileResponseTarget: boolean;
  declare readonly beginUrlValue: string;
  declare readonly hasBeginUrlValue: boolean;
  declare readonly finishUrlValue: string;
  declare readonly hasFinishUrlValue: boolean;
  declare readonly successRedirectUrlValue: string;
  declare readonly hasSuccessRedirectUrlValue: boolean;
  declare readonly optionsUrlValue: string;
  declare readonly verificationUrlValue: string;
  declare readonly checkpointVersionValue: string;
  declare readonly hasCheckpointVersionValue: boolean;
  declare readonly turnstileSiteKeyValue: string;
  declare readonly turnstileErrorMessageValue: string;

  get descriptionValue(): string {
    if (this.hasDescriptionTarget) {
      return this.descriptionTarget.value || "";
    }
    return "";
  }

  get requestBeginUrl(): string {
    if (this.hasBeginUrlValue) {
      return this.beginUrlValue;
    }
    return this.optionsUrlValue;
  }

  get requestFinishUrl(): string {
    if (this.hasFinishUrlValue) {
      return this.finishUrlValue;
    }
    return this.verificationUrlValue;
  }

  get redirectUrl(): string {
    if (this.hasSuccessRedirectUrlValue) {
      return this.successRedirectUrlValue;
    }
    return "";
  }

  async register(event: Event) {
    event.preventDefault();
    this.clearMessages();

    // Check WebAuthn support
    if (!passkeysSupported()) {
      this.showError("このブラウザはPasskeyに対応していません");
      return;
    }

    try {
      const turnstileToken = await this.ensureTurnstileToken();
      this.showStatus("認証オプションを取得中...");

      // Step 1: Get registration options from server
      const begun = await postCeremonyJson(
        this.requestBeginUrl,
        { "cf-turnstile-response": turnstileToken },
        "オプションの取得に失敗しました",
      );

      if (begun === CEREMONY_REDIRECTED) {
        return;
      }

      this.showStatus("認証器でPasskeyを作成中...");

      // Step 2: Create credential with authenticator
      const credential = await createCredential(readObject(begun, "options"));

      this.showStatus("サーバーで検証中...");

      // Step 3: Send credential to server for verification
      const verified = await postCeremonyJson(
        this.requestFinishUrl,
        {
          challenge_id: readString(begun, "challenge_id"),
          credential,
          description: this.descriptionValue,
          checkpoint_version: this.hasCheckpointVersionValue
            ? this.checkpointVersionValue
            : undefined,
        },
        "登録に失敗しました",
      );

      if (verified === CEREMONY_REDIRECTED) {
        return;
      }

      // Step 4: Success - redirect
      this.showStatus("登録完了！リダイレクト中...");
      const target = readNonEmptyString(verified, "redirect_url") ?? this.redirectUrl;
      if (target) {
        window.location.href = target;
      } else {
        window.location.reload();
      }
    } catch (error) {
      this.showError(
        ceremonyErrorMessage(error, {
          NotAllowedError: "認証がキャンセルされました",
          InvalidStateError: "このPasskeyは既に登録されています",
          fallback: "登録中にエラーが発生しました",
        }),
      );
    }
  }

  async ensureTurnstileToken(): Promise<string> {
    if (this.hasTurnstileResponseTarget && this.turnstileResponseTarget.value) {
      return this.turnstileResponseTarget.value;
    }

    const token = await solveInvisibleTurnstile(
      this.turnstileSiteKeyValue,
      this.turnstileErrorMessageValue,
      /* v8 ignore next -- Stimulus controllers always attach to an HTMLElement */
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
    /* v8 ignore next -- status is optional; the success path already covers the present arm */
    if (this.hasStatusTarget) {
      this.statusTarget.classList.add("hidden");
    }
  }

  showStatus(message: string) {
    /* v8 ignore next -- status is optional on some Stimulus markups */
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
