import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// The passkey requirement of the sign-up checkpoint. It runs the same ceremony as
// `@/features/auth/passkeys/PasskeyRegistrationPanel`, minus the Turnstile step this page's
// partial never had. What belongs here is what this component decides: what it refuses to start
// on, what each of the two POSTs carries, and where the visitor is sent once the server clears the
// requirement.
import SignUpPasskeyRegistration from "@/features/auth/signup/SignUpPasskeyRegistration";

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

const BEGIN_URL = "/sign/up/check/telephone/passkey/options";
const FINISH_URL = "/sign/up/check/telephone/passkey/verification";
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

const PROPS = {
  title: "パスキー登録",
  begin_url: BEGIN_URL,
  finish_url: FINISH_URL,
  success_redirect_url: "/sign/up/check/telephone/passcode?ri=jp",
  checkpoint_version: 2,
  description_label: "端末の名前",
  description_placeholder: "iPhone",
  submit_label: "登録する",
};

/** The component navigates on success; jsdom has no navigation, so the assignment is observed. */
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
});

afterEach(() => {
  root.unmount();
  container.remove();
  vi.unstubAllGlobals();
});

describe("SignUpPasskeyRegistration", () => {
  it("posts the attestation and description, with no Turnstile step", async () => {
    const credentials = stubCredentialsApi();
    credentials.create.mockResolvedValue(attestationCredential());
    const fetchMock = stubCeremonyFetch(
      jsonResponse(BEGUN),
      jsonResponse({ redirect_url: "/sign/up/check/telephone/passcode?ri=jp" }),
    );
    const navigation = stubNavigation();
    mount(<SignUpPasskeyRegistration {...PROPS} />);

    click("button");
    await flush();

    const begin = requestAt(fetchMock, 0);
    expect(begin.url).toBe(BEGIN_URL);
    expect(begin.body).toEqual({});

    const finish = requestAt(fetchMock, 1);
    expect(finish.url).toBe(FINISH_URL);
    expect(finish.body).toMatchObject({
      challenge_id: "challenge-1",
      description: "",
      checkpoint_version: 2,
      credential: { id: "cred-id", type: "public-key" },
    });

    expect(container.textContent).toContain("登録完了！リダイレクト中...");
    expect(navigation.href()).toBe("/sign/up/check/telephone/passcode?ri=jp");
  });

  it("falls back to its own success url when the server names no redirect", async () => {
    const credentials = stubCredentialsApi();
    credentials.create.mockResolvedValue(attestationCredential());
    stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse({}));
    const navigation = stubNavigation();
    mount(<SignUpPasskeyRegistration {...PROPS} />);

    click("button");
    await flush();

    expect(navigation.href()).toBe("/sign/up/check/telephone/passcode?ri=jp");
  });

  it("reloads when neither the server nor the page names a destination", async () => {
    const credentials = stubCredentialsApi();
    credentials.create.mockResolvedValue(attestationCredential());
    stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse({}));
    const navigation = stubNavigation();
    mount(
      <SignUpPasskeyRegistration
        {...PROPS}
        success_redirect_url=""
      />,
    );

    click("button");
    await flush();

    expect(navigation.reloaded()).toBe(true);
  });

  describe("refuses to start", () => {
    it("when the browser cannot do WebAuthn", async () => {
      vi.stubGlobal("PublicKeyCredential", undefined);
      mount(<SignUpPasskeyRegistration {...PROPS} />);

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
      mount(<SignUpPasskeyRegistration {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe("上限に達しています");
    });

    it("falls back to its own copy when the error carries no message", async () => {
      stubCeremonyFetch(jsonResponse({}, 422));
      mount(<SignUpPasskeyRegistration {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "オプションの取得に失敗しました",
      );
    });

    it("fails loudly when the options response carries no challenge id", async () => {
      stubCeremonyFetch(jsonResponse({ options: CREATION_OPTIONS }));
      mount(<SignUpPasskeyRegistration {...PROPS} />);

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
      mount(<SignUpPasskeyRegistration {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe("証明書が不正です");
    });

    it("rejects a credential the authenticator returned in the wrong shape", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue({ id: "cred-id", type: "public-key" });
      stubCeremonyFetch(jsonResponse(BEGUN));
      mount(<SignUpPasskeyRegistration {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe("登録に失敗しました");
    });

    it.each([401, 302])("reloads onto the sign-in screen on %i", async (status) => {
      stubCeremonyFetch(textResponse("", status));
      const navigation = stubNavigation();
      mount(<SignUpPasskeyRegistration {...PROPS} />);

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
      mount(<SignUpPasskeyRegistration {...PROPS} />);

      click("button");
      await flush();

      expect(navigation.reloaded()).toBe(true);
    });

    it("falls back to its own copy for a non-JSON failure", async () => {
      stubCeremonyFetch(textResponse("<html>oops</html>", 500, "text/html"));
      mount(<SignUpPasskeyRegistration {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "オプションの取得に失敗しました",
      );
    });

    it("falls back to its own copy for a failure with no content-type header at all", async () => {
      stubCeremonyFetch(new Response(null, { status: 500 }));
      mount(<SignUpPasskeyRegistration {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "オプションの取得に失敗しました",
      );
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
      mount(<SignUpPasskeyRegistration {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(message);
    });

    it("falls back when the failure is not an Error at all", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockRejectedValue("nope");
      stubCeremonyFetch(jsonResponse(BEGUN));
      mount(<SignUpPasskeyRegistration {...PROPS} />);

      click("button");
      await flush();

      expect(container.querySelector("[role='alert']")?.textContent).toBe(
        "登録中にエラーが発生しました",
      );
    });
  });

  it("reports no transports when the authenticator does not support the query", async () => {
    const credentials = stubCredentialsApi();
    credentials.create.mockResolvedValue(attestationCredential({ transports: null }));
    const fetchMock = stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse({}));
    stubNavigation();
    mount(<SignUpPasskeyRegistration {...PROPS} />);

    click("button");
    await flush();

    expect(requestAt(fetchMock, 1).body).toMatchObject({
      credential: { response: { transports: [] } },
    });
  });
});
