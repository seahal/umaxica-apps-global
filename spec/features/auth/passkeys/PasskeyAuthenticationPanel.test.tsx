import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// The React port of `passkey_authentication_controller.js`. The credential ceremony lives in
// `@/features/auth/passkeys/webauthn` and the invisible Turnstile token in
// `@/features/auth/passkeys/invisibleTurnstile`; both have their own specs. What belongs here is
// what this component decides: what it refuses to start on, what each of the two POSTs carries,
// and where the visitor is sent once the server accepts the assertion.
import PasskeyAuthenticationPanel from "@/features/auth/passkeys/PasskeyAuthenticationPanel";
import type { TurnstileOptions } from "@/lib/turnstile";

import {
  jsonResponse,
  requestAt,
  stubCeremonyFetch,
  textResponse,
} from "../../../support/ceremony";
import {
  assertionCredential,
  credentialError,
  stubCredentialsApi,
} from "../../../support/webauthn";

declare global {
  // React reads this flag off the global object to decide whether `act` is allowed.
  var IS_REACT_ACT_ENVIRONMENT: boolean;
}
globalThis.IS_REACT_ACT_ENVIRONMENT = true;

const OPTIONS_URL = "/in/passkeys/options";
const VERIFICATION_URL = "/in/passkeys/verification";
const BEGUN = { challenge_id: "challenge-1", options: { challenge: "Y2hhbGxlbmdl" } };

let container: HTMLDivElement;
let root: Root;

const mount = (element: React.ReactElement) => {
  container = document.createElement("div");
  document.body.append(container);
  root = createRoot(container);
  act(() => {
    root.render(element);
  });
};

const type = (selector: string, value: string) => {
  const input = container.querySelector<HTMLInputElement>(selector);
  const descriptor = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value");
  act(() => {
    if (input && descriptor?.set) {
      descriptor.set.call(input, value);
      input.dispatchEvent(new Event("input", { bubbles: true }));
    }
  });
};

const click = (selector: string) => {
  const button = container.querySelector<HTMLButtonElement>(selector);
  expect(button).not.toBeNull();
  act(() => {
    button?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  });
};

const flush = async () => {
  await act(async () => {
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
  });
};

let rendered: { container: HTMLElement; options: TurnstileOptions }[];
let render: ReturnType<typeof vi.fn>;

function stubTurnstile() {
  document.head.innerHTML +=
    '<script src="https://challenges.cloudflare.com/turnstile/v0/api.js"></script>';
  rendered = [];
  render = vi.fn((widgetContainer: HTMLElement, options: TurnstileOptions) => {
    rendered.push({ container: widgetContainer, options });
    // Solves the widget on the same tick `render` is called, exactly as a real invisible widget
    // does for a Turnstile deployment configured to auto-solve.
    queueMicrotask(() => options.callback("solved-token"));
    return "widget-1";
  });
  vi.stubGlobal("turnstile", { render, execute: vi.fn(), remove: vi.fn() });
}

const PROPS = {
  options_url: OPTIONS_URL,
  verification_url: VERIFICATION_URL,
  region: "jp",
  identifier_param: "email",
  turnstile_site_key: "site-key",
  turnstile_error_message: "Security verification failed. Please refresh and try again.",
  field: {
    label: "メールアドレス",
    placeholder: "you@example.test",
    min_length: 1,
    max_length: 255,
    pattern: "",
  },
  submit_label: "サインイン",
};

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

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="a-token">';
  stubCredentialsApi();
  stubTurnstile();
});

afterEach(() => {
  root.unmount();
  container.remove();
  vi.unstubAllGlobals();
});

describe("PasskeyAuthenticationPanel", () => {
  it("posts the identifier and the solved Turnstile token, then the assertion", async () => {
    const credentials = stubCredentialsApi();
    credentials.get.mockResolvedValue(assertionCredential());
    const fetchMock = stubCeremonyFetch(
      jsonResponse(BEGUN),
      jsonResponse({ status: "ok", redirect_url: "/home" }),
    );
    const navigation = stubNavigation();
    mount(<PasskeyAuthenticationPanel {...PROPS} />);
    type("#identifier", "someone@example.test");

    click("button");
    await flush();

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

  it("omits the region from both requests when the surface carries none", async () => {
    const credentials = stubCredentialsApi();
    credentials.get.mockResolvedValue(assertionCredential());
    const fetchMock = stubCeremonyFetch(
      jsonResponse(BEGUN),
      jsonResponse({ status: "ok", redirect_url: "/home" }),
    );
    stubNavigation();
    mount(
      <PasskeyAuthenticationPanel
        {...PROPS}
        region=""
      />,
    );
    type("#identifier", "someone@example.test");

    click("button");
    await flush();

    expect(requestAt(fetchMock, 0).body).not.toHaveProperty("ri");
    expect(requestAt(fetchMock, 1).body).not.toHaveProperty("ri");
  });

  it("mounts the invisible widget on its own root element", async () => {
    const credentials = stubCredentialsApi();
    credentials.get.mockResolvedValue(assertionCredential());
    stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse({ status: "ok", redirect_url: "/home" }));
    stubNavigation();
    mount(<PasskeyAuthenticationPanel {...PROPS} />);
    type("#identifier", "someone@example.test");

    click("button");
    await flush();

    expect(rendered[0]?.container.parentElement).toBe(container.firstElementChild);
  });

  it("follows the TOTP challenge when the server asks for a second factor", async () => {
    const credentials = stubCredentialsApi();
    credentials.get.mockResolvedValue(assertionCredential());
    stubCeremonyFetch(
      jsonResponse(BEGUN),
      jsonResponse({ status: "totp_required", redirect_url: "/in/totp" }),
    );
    const navigation = stubNavigation();
    mount(<PasskeyAuthenticationPanel {...PROPS} />);
    type("#identifier", "someone@example.test");

    click("button");
    await flush();

    expect(container.textContent).toContain("二段階認証が必要です...");
    expect(navigation.href()).toBe("/in/totp");
  });

  describe("refuses to start", () => {
    it("when the browser cannot do WebAuthn", async () => {
      vi.stubGlobal("PublicKeyCredential", undefined);
      mount(<PasskeyAuthenticationPanel {...PROPS} />);
      type("#identifier", "someone@example.test");

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "このブラウザはPasskeyに対応していません",
      );
    });

    it("when no identifier was typed", async () => {
      mount(<PasskeyAuthenticationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "メールアドレスまたはIDを入力してください",
      );
    });

    it("when the identifier is only whitespace", async () => {
      mount(<PasskeyAuthenticationPanel {...PROPS} />);
      type("#identifier", "   ");

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "メールアドレスまたはIDを入力してください",
      );
    });
  });

  describe("a server that refuses the ceremony", () => {
    it("shows the error the options request returned", async () => {
      stubCeremonyFetch(jsonResponse({ error: "この識別子では利用できません" }, 422));
      mount(<PasskeyAuthenticationPanel {...PROPS} />);
      type("#identifier", "someone@example.test");

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "この識別子では利用できません",
      );
    });

    it("falls back to its own copy when the error carries no message", async () => {
      stubCeremonyFetch(jsonResponse({}, 422));
      mount(<PasskeyAuthenticationPanel {...PROPS} />);
      type("#identifier", "someone@example.test");

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "オプションの取得に失敗しました",
      );
    });

    it("shows the error the verification request returned", async () => {
      const credentials = stubCredentialsApi();
      credentials.get.mockResolvedValue(assertionCredential());
      stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse({ error: "鍵が一致しません" }, 422));
      mount(<PasskeyAuthenticationPanel {...PROPS} />);
      type("#identifier", "someone@example.test");

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe("鍵が一致しません");
    });

    it.each([401, 302])("reloads onto the sign-in screen on %i", async (status) => {
      stubCeremonyFetch(textResponse("", status));
      const navigation = stubNavigation();
      mount(<PasskeyAuthenticationPanel {...PROPS} />);
      type("#identifier", "someone@example.test");

      click("button");
      await flush();

      expect(navigation.reloaded()).toBe(true);
      expect(container.querySelector("[role='alert']")).toBeNull();
    });

    it("reloads when the session ends between the two requests", async () => {
      const credentials = stubCredentialsApi();
      credentials.get.mockResolvedValue(assertionCredential());
      stubCeremonyFetch(jsonResponse(BEGUN), textResponse("", 401));
      const navigation = stubNavigation();
      mount(<PasskeyAuthenticationPanel {...PROPS} />);
      type("#identifier", "someone@example.test");

      click("button");
      await flush();

      expect(navigation.reloaded()).toBe(true);
    });

    it("fails loudly when the options response carries no challenge id", async () => {
      stubCeremonyFetch(jsonResponse({ options: { challenge: "Y2hhbGxlbmdl" } }));
      mount(<PasskeyAuthenticationPanel {...PROPS} />);
      type("#identifier", "someone@example.test");

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "オプションの取得に失敗しました",
      );
    });

    it("fails loudly when the options response carries no options", async () => {
      stubCeremonyFetch(jsonResponse({ challenge_id: "challenge-1" }));
      mount(<PasskeyAuthenticationPanel {...PROPS} />);
      type("#identifier", "someone@example.test");

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "オプションの取得に失敗しました",
      );
    });

    it("falls back to its own copy for a non-JSON failure", async () => {
      stubCeremonyFetch(textResponse("<html>oops</html>", 500, "text/html"));
      mount(<PasskeyAuthenticationPanel {...PROPS} />);
      type("#identifier", "someone@example.test");

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "オプションの取得に失敗しました",
      );
    });

    it("falls back to its own copy for a failure with no content-type header at all", async () => {
      stubCeremonyFetch(new Response(null, { status: 500 }));
      mount(<PasskeyAuthenticationPanel {...PROPS} />);
      type("#identifier", "someone@example.test");

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "オプションの取得に失敗しました",
      );
    });

    it.each<[Record<string, string>, string]>([
      [{ status: "ok" }, "no redirect url"],
      [{ redirect_url: "/home" }, "no status"],
      [{ status: "unknown", redirect_url: "/home" }, "a status it does not know"],
    ])("refuses a verification answer with %s", async (body) => {
      const credentials = stubCredentialsApi();
      credentials.get.mockResolvedValue(assertionCredential());
      stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse(body));
      mount(<PasskeyAuthenticationPanel {...PROPS} />);
      type("#identifier", "someone@example.test");

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe("予期しない応答です");
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
      mount(<PasskeyAuthenticationPanel {...PROPS} />);
      type("#identifier", "someone@example.test");

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(message);
    });
  });

  describe("the Turnstile token", () => {
    it("reports the failure when no widget can be solved", async () => {
      mount(
        <PasskeyAuthenticationPanel
          {...PROPS}
          turnstile_site_key=""
        />,
      );
      type("#identifier", "someone@example.test");

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "Security verification failed. Please refresh and try again.",
      );
    });

    it("falls back to the default message when the surface sent none", async () => {
      mount(
        <PasskeyAuthenticationPanel
          {...PROPS}
          turnstile_site_key=""
          turnstile_error_message=""
        />,
      );
      type("#identifier", "someone@example.test");

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "Security verification failed. Please refresh and try again.",
      );
    });
  });
});
