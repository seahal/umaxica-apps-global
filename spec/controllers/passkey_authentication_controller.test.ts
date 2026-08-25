// Signing in with a passkey on the surfaces that do not boot React.
//
// The credential ceremony lives in `@/features/auth/passkeys/webauthn` and the request/response
// handling in `@/controllers/passkey_ceremony`; both have their own specs. What belongs here is
// what this controller decides: what it refuses to start on, what each of the two POSTs carries,
// and where the visitor is sent once the server accepts the assertion.
import { Controller } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import PasskeyAuthenticationController from "@/controllers/passkey_authentication_controller";

import { jsonResponse, requestAt, stubCeremonyFetch, textResponse } from "../support/ceremony";
import { mountController } from "../support/stimulus";
import {
  REQUEST_OPTIONS,
  assertionCredential,
  credentialError,
  stubCredentialsApi,
} from "../support/webauthn";

const OPTIONS_URL = "/in/passkeys/options";
const VERIFICATION_URL = "/in/passkeys/verification";

function markup({
  identifier = "someone@example.test",
  region = "jp",
  identifierParam = "",
  turnstileToken = "solved-token",
}: {
  identifier?: string;
  region?: string | null;
  identifierParam?: string;
  turnstileToken?: string;
} = {}): string {
  return `
    <div data-controller="passkey-authentication"
         data-passkey-authentication-options-url-value="${OPTIONS_URL}"
         data-passkey-authentication-verification-url-value="${VERIFICATION_URL}"
         ${region === null ? "" : `data-passkey-authentication-region-value="${region}"`}
         ${identifierParam ? `data-passkey-authentication-identifier-param-value="${identifierParam}"` : ""}
         data-passkey-authentication-turnstile-site-key-value="site-key">
      <input type="text" value="${identifier}" data-passkey-authentication-target="identifier">
      <input type="hidden" value="${turnstileToken}"
             data-passkey-authentication-target="turnstileResponse">
      <p data-passkey-authentication-target="error" class="hidden"></p>
      <p data-passkey-authentication-target="status" class="hidden"></p>
    </div>
  `;
}

const mount = (options?: Parameters<typeof markup>[0]) =>
  mountController("passkey-authentication", PasskeyAuthenticationController, markup(options));

function messageText(element: HTMLElement, target: "error" | "status"): string {
  return (
    element.querySelector(`[data-passkey-authentication-target="${target}"]`)?.textContent ?? ""
  );
}

/** The controller navigates on success; jsdom has no navigation, so the assignment is observed. */
function stubNavigation(): { href: () => string; reloaded: () => boolean } {
  let href = "";
  let reloaded = false;

  Object.defineProperty(window, "location", {
    value: {
      get href() {
        return href;
      },
      set href(value: string) {
        href = value;
      },
      origin: "https://example.test",
      search: "",
      reload: () => {
        reloaded = true;
      },
    },
    configurable: true,
    writable: true,
  });

  return { href: () => href, reloaded: () => reloaded };
}

const BEGUN = { challenge_id: "challenge-1", options: REQUEST_OPTIONS };

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="a-token">';
  stubCredentialsApi();
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("PasskeyAuthenticationController", () => {
  it("is a Stimulus controller, so the registry can register it", () => {
    expect(PasskeyAuthenticationController.prototype).toBeInstanceOf(Controller);
  });

  describe("a ceremony the server accepts", () => {
    it("posts the identifier and the Turnstile token, then the assertion", async () => {
      const credentials = stubCredentialsApi();
      credentials.get.mockResolvedValue(assertionCredential());
      const fetchMock = stubCeremonyFetch(
        jsonResponse(BEGUN),
        jsonResponse({ status: "ok", redirect_url: "/home" }),
      );
      const navigation = stubNavigation();
      const { controller } = await mount();

      await controller.authenticate(new Event("click"));

      const options = requestAt(fetchMock, 0);
      expect(options.url).toBe(OPTIONS_URL);
      expect(options.body).toEqual({
        email: "someone@example.test",
        "cf-turnstile-response": "solved-token",
        ri: "jp",
      });

      const verification = requestAt(fetchMock, 1);
      expect(verification.url).toBe(VERIFICATION_URL);
      expect(verification.body).toMatchObject({
        challenge_id: "challenge-1",
        credential: { id: "cred-id", type: "public-key" },
        ri: "jp",
      });

      expect(navigation.href()).toBe("/home");
    });

    it("sends the identifier under the parameter name the server named", async () => {
      const credentials = stubCredentialsApi();
      credentials.get.mockResolvedValue(assertionCredential());
      const fetchMock = stubCeremonyFetch(
        jsonResponse(BEGUN),
        jsonResponse({ status: "ok", redirect_url: "/home" }),
      );
      stubNavigation();
      const { controller } = await mount({ identifierParam: "login_id" });

      await controller.authenticate(new Event("click"));

      expect(requestAt(fetchMock, 0).body).toMatchObject({ login_id: "someone@example.test" });
    });

    it("omits the region when the surface carries none", async () => {
      const credentials = stubCredentialsApi();
      credentials.get.mockResolvedValue(assertionCredential());
      const fetchMock = stubCeremonyFetch(
        jsonResponse(BEGUN),
        jsonResponse({ status: "ok", redirect_url: "/home" }),
      );
      stubNavigation();
      const { controller } = await mount({ region: null });

      await controller.authenticate(new Event("click"));

      expect(requestAt(fetchMock, 0).body).not.toHaveProperty("ri");
    });

    it("follows the TOTP challenge when the server asks for a second factor", async () => {
      const credentials = stubCredentialsApi();
      credentials.get.mockResolvedValue(assertionCredential());
      stubCeremonyFetch(
        jsonResponse(BEGUN),
        jsonResponse({ status: "totp_required", redirect_url: "/in/totp" }),
      );
      const navigation = stubNavigation();
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(messageText(element, "status")).toBe("二段階認証が必要です...");
      expect(navigation.href()).toBe("/in/totp");
    });
  });

  describe("refuses to start", () => {
    it("when the browser cannot do WebAuthn", async () => {
      vi.stubGlobal("PublicKeyCredential", undefined);
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(messageText(element, "error")).toBe("このブラウザはPasskeyに対応していません");
    });

    it("when no identifier was typed", async () => {
      const { controller, element } = await mount({ identifier: "" });

      await controller.authenticate(new Event("click"));

      expect(messageText(element, "error")).toBe("メールアドレスまたはIDを入力してください");
    });

    it("prevents the click from submitting the surrounding form", async () => {
      const { controller } = await mount({ identifier: "" });
      const event = new Event("click", { cancelable: true });

      await controller.authenticate(event);

      expect(event.defaultPrevented).toBe(true);
    });
  });

  describe("a server that refuses the ceremony", () => {
    it("shows the error the options request returned", async () => {
      stubCeremonyFetch(jsonResponse({ error: "この識別子では利用できません" }, 422));
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(messageText(element, "error")).toBe("この識別子では利用できません");
    });

    it("falls back to its own copy when the error carries no message", async () => {
      stubCeremonyFetch(jsonResponse({}, 422));
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(messageText(element, "error")).toBe("オプションの取得に失敗しました");
    });

    it("shows the error the verification request returned", async () => {
      const credentials = stubCredentialsApi();
      credentials.get.mockResolvedValue(assertionCredential());
      stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse({ error: "鍵が一致しません" }, 422));
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(messageText(element, "error")).toBe("鍵が一致しません");
    });

    it.each([401, 302])("reloads onto the sign-in screen on %i", async (status) => {
      stubCeremonyFetch(textResponse("", status));
      const navigation = stubNavigation();
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(navigation.reloaded()).toBe(true);
      expect(messageText(element, "error")).toBe("");
    });

    it("reloads when the session ends between the two requests", async () => {
      const credentials = stubCredentialsApi();
      credentials.get.mockResolvedValue(assertionCredential());
      stubCeremonyFetch(jsonResponse(BEGUN), textResponse("", 401));
      const navigation = stubNavigation();
      const { controller } = await mount();

      await controller.authenticate(new Event("click"));

      expect(navigation.reloaded()).toBe(true);
    });

    it("falls back to its own copy for a non-JSON failure", async () => {
      stubCeremonyFetch(textResponse("<html>oops</html>", 500, "text/html"));
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(messageText(element, "error")).toBe("オプションの取得に失敗しました");
    });

    it("falls back to its own copy for a failure with no content type at all", async () => {
      stubCeremonyFetch(textResponse("", 500));
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(messageText(element, "error")).toBe("オプションの取得に失敗しました");
    });

    it.each<[Record<string, string>, string]>([
      [{ status: "ok" }, "no redirect url"],
      [{ redirect_url: "/home" }, "no status"],
      [{ status: "unknown", redirect_url: "/home" }, "a status it does not know"],
    ])("refuses a verification answer with %s", async (body) => {
      const credentials = stubCredentialsApi();
      credentials.get.mockResolvedValue(assertionCredential());
      stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse(body));
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(messageText(element, "error")).toBe("予期しない応答です");
    });
  });

  describe("reports the authenticator's own failures", () => {
    it.each([
      ["NotAllowedError", "認証がキャンセルされました"],
      ["SecurityError", "セキュリティエラーが発生しました"],
    ])("maps %s onto its own copy", async (name, message) => {
      const credentials = stubCredentialsApi();
      credentials.get.mockRejectedValue(credentialError(name));
      stubCeremonyFetch(jsonResponse(BEGUN));
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(messageText(element, "error")).toBe(message);
    });

    it("falls back when the failure is not an Error at all", async () => {
      const credentials = stubCredentialsApi();
      credentials.get.mockRejectedValue("nope");
      stubCeremonyFetch(jsonResponse(BEGUN));
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(messageText(element, "error")).toBe("認証中にエラーが発生しました");
    });
  });

  describe("the Turnstile token", () => {
    it("reuses the token already in the hidden field", async () => {
      const credentials = stubCredentialsApi();
      credentials.get.mockResolvedValue(assertionCredential());
      const fetchMock = stubCeremonyFetch(
        jsonResponse(BEGUN),
        jsonResponse({ status: "ok", redirect_url: "/home" }),
      );
      stubNavigation();
      const { controller } = await mount({ turnstileToken: "already-solved" });

      await controller.authenticate(new Event("click"));

      expect(requestAt(fetchMock, 0).body).toMatchObject({
        "cf-turnstile-response": "already-solved",
      });
    });

    it("reports the failure when no widget can be solved", async () => {
      const { controller, element } = await mount({ turnstileToken: "" });

      await controller.authenticate(new Event("click"));

      expect(messageText(element, "error")).toBe(
        "Security verification failed. Please refresh and try again.",
      );
    });
  });
});
