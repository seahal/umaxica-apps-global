import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// The React port of `passkey_registration_controller.js`. The credential ceremony lives in
// `@/features/auth/passkeys/webauthn` and the invisible Turnstile token in
// `@/features/auth/passkeys/invisibleTurnstile`; both have their own specs. What belongs here is
// what this component decides: what it refuses to start on, what each of the two POSTs carries,
// and where the visitor is sent once the server accepts the attestation.
import PasskeyRegistrationPanel from "@/features/auth/passkeys/PasskeyRegistrationPanel";
import type { TurnstileOptions } from "@/lib/turnstile";

import {
  jsonResponse,
  requestAt,
  stubCeremonyFetch,
  textResponse,
} from "../../../support/ceremony";
import {
  CREATION_OPTIONS,
  attestationCredential,
  credentialError,
  stubCredentialsApi,
} from "../../../support/webauthn";

declare global {
  // React reads this flag off the global object to decide whether `act` is allowed.
  var IS_REACT_ACT_ENVIRONMENT: boolean;
}
globalThis.IS_REACT_ACT_ENVIRONMENT = true;

const OPTIONS_URL = "/settings/passkeys/options";
const VERIFICATION_URL = "/settings/passkeys/verification";
const BEGUN = { challenge_id: "challenge-1", options: CREATION_OPTIONS };

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
    queueMicrotask(() => options.callback("solved-token"));
    return "widget-1";
  });
  vi.stubGlobal("turnstile", { render, execute: vi.fn(), remove: vi.fn() });
}

const PROPS = {
  options_url: OPTIONS_URL,
  verification_url: VERIFICATION_URL,
  turnstile_site_key: "site-key",
  turnstile_error_message: "Security verification failed. Please refresh and try again.",
  description_label: "端末の名前",
  description_placeholder: "iPhone",
  submit_label: "登録",
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

describe("PasskeyRegistrationPanel", () => {
  it("posts the solved Turnstile token, then the attestation and its description", async () => {
    const credentials = stubCredentialsApi();
    credentials.create.mockResolvedValue(attestationCredential());
    const fetchMock = stubCeremonyFetch(
      jsonResponse(BEGUN),
      jsonResponse({ redirect_url: "/settings/passkeys" }),
    );
    const navigation = stubNavigation();
    mount(<PasskeyRegistrationPanel {...PROPS} />);
    type("input[type=text]", "iPhone");

    click("button");
    await flush();

    const begin = requestAt(fetchMock, 0);
    expect(begin.url).toBe(OPTIONS_URL);
    expect(begin.body).toEqual({ "cf-turnstile-response": "solved-token" });

    const finish = requestAt(fetchMock, 1);
    expect(finish.url).toBe(VERIFICATION_URL);
    expect(finish.body).toMatchObject({
      challenge_id: "challenge-1",
      description: "iPhone",
      credential: { id: "cred-id", type: "public-key" },
    });

    expect(container.textContent).toContain("登録完了！リダイレクト中...");
    expect(navigation.href()).toBe("/settings/passkeys");
  });

  it("reports no transports when the authenticator does not support the query", async () => {
    const credentials = stubCredentialsApi();
    credentials.create.mockResolvedValue(attestationCredential({ transports: null }));
    const fetchMock = stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse({ redirect_url: "/x" }));
    stubNavigation();
    mount(<PasskeyRegistrationPanel {...PROPS} />);

    click("button");
    await flush();

    expect(requestAt(fetchMock, 1).body).toMatchObject({
      credential: { response: { transports: [] } },
    });
  });

  it("sends an empty description when none was typed", async () => {
    const credentials = stubCredentialsApi();
    credentials.create.mockResolvedValue(attestationCredential());
    const fetchMock = stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse({ redirect_url: "/x" }));
    stubNavigation();
    mount(<PasskeyRegistrationPanel {...PROPS} />);

    click("button");
    await flush();

    expect(requestAt(fetchMock, 1).body).toMatchObject({ description: "" });
  });

  it("reloads when the server names no redirect", async () => {
    const credentials = stubCredentialsApi();
    credentials.create.mockResolvedValue(attestationCredential());
    stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse({}));
    const navigation = stubNavigation();
    mount(<PasskeyRegistrationPanel {...PROPS} />);

    click("button");
    await flush();

    expect(navigation.reloaded()).toBe(true);
  });

  describe("refuses to start", () => {
    it("when the browser cannot do WebAuthn", async () => {
      vi.stubGlobal("PublicKeyCredential", undefined);
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "このブラウザはPasskeyに対応していません",
      );
    });
  });

  describe("a server that refuses the ceremony", () => {
    it("shows the error the options request returned", async () => {
      stubCeremonyFetch(jsonResponse({ error: "上限に達しています" }, 422));
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe("上限に達しています");
    });

    it("falls back to its own copy when the error carries no message", async () => {
      stubCeremonyFetch(jsonResponse({}, 422));
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "オプションの取得に失敗しました",
      );
    });

    it("shows the error the verification request returned", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse({ error: "証明書が不正です" }, 422));
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe("証明書が不正です");
    });

    it("falls back to its own copy when the verification error carries no message", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse({}, 422));
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe("登録に失敗しました");
    });

    it.each([401, 302])("reloads onto the sign-in screen on %i", async (status) => {
      stubCeremonyFetch(textResponse("", status));
      const navigation = stubNavigation();
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(navigation.reloaded()).toBe(true);
      expect(container.querySelector("[role='alert']")).toBeNull();
    });

    it("reloads when the session ends between the two requests", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      stubCeremonyFetch(jsonResponse(BEGUN), textResponse("", 401));
      const navigation = stubNavigation();
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(navigation.reloaded()).toBe(true);
    });

    it("falls back to its own copy for a non-JSON failure", async () => {
      stubCeremonyFetch(textResponse("<html>oops</html>", 500, "text/html"));
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "オプションの取得に失敗しました",
      );
    });

    it("falls back to its own copy for a failure with no content-type header at all", async () => {
      stubCeremonyFetch(new Response(null, { status: 500 }));
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "オプションの取得に失敗しました",
      );
    });

    it("fails loudly when the options response carries no challenge id", async () => {
      stubCeremonyFetch(jsonResponse({ options: CREATION_OPTIONS }));
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "オプションの取得に失敗しました",
      );
    });

    it("fails loudly when the options response carries no options", async () => {
      stubCeremonyFetch(jsonResponse({ challenge_id: "challenge-1" }));
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "オプションの取得に失敗しました",
      );
    });

    it("rejects a credential the authenticator returned in the wrong shape", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue({ id: "cred-id", type: "public-key" });
      stubCeremonyFetch(jsonResponse(BEGUN));
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe("登録に失敗しました");
    });

    it("rejects when the authenticator returns no credential at all", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(null);
      stubCeremonyFetch(jsonResponse(BEGUN));
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe("登録に失敗しました");
    });
  });

  describe("reports the authenticator's own failures", () => {
    it.each([
      ["NotAllowedError", "認証がキャンセルされました"],
      ["InvalidStateError", "このPasskeyは既に登録されています"],
    ])("maps %s onto its own copy", async (name, message) => {
      const credentials = stubCredentialsApi();
      credentials.create.mockRejectedValue(credentialError(name));
      stubCeremonyFetch(jsonResponse(BEGUN));
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(message);
    });

    it("shows the failure's own message when it has one", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockRejectedValue(new Error("認証器が応答しません"));
      stubCeremonyFetch(jsonResponse(BEGUN));
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe("認証器が応答しません");
    });

    it("falls back when the failure is not an Error at all", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockRejectedValue("nope");
      stubCeremonyFetch(jsonResponse(BEGUN));
      mount(<PasskeyRegistrationPanel {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "登録中にエラーが発生しました",
      );
    });
  });

  describe("the Turnstile token", () => {
    it("reports the failure when no widget can be solved", async () => {
      mount(
        <PasskeyRegistrationPanel
          {...PROPS}
          turnstile_site_key=""
        />,
      );

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "Security verification failed. Please refresh and try again.",
      );
    });

    it("falls back to the default message when the surface sent none", async () => {
      mount(
        <PasskeyRegistrationPanel
          {...PROPS}
          turnstile_site_key=""
          turnstile_error_message=""
        />,
      );

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "Security verification failed. Please refresh and try again.",
      );
    });
  });
});
