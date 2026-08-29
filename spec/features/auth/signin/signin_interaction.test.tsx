import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  jsonResponse as httpJsonResponse,
  requestBody,
  stubFetchQueue,
} from "../../../support/http";
import { containing } from "../../../support/matchers";
import { present } from "../../../support/present";

// Unlike signin_screens.test.tsx (static markup only), these tests mount the components and fire
// real DOM events, which is the only way to reach the submit, resend and WebAuthn handlers that
// moved out of Stimulus.
const post = vi.fn();
const patch = vi.fn();
const setData = vi.fn();

vi.mock("@inertiajs/react", () => ({
  useForm: (initial: Record<string, unknown>) => ({
    data: initial,
    setData,
    post,
    patch,
    processing: false,
  }),
}));

import type { getAssertion as realGetAssertion } from "@/features/auth/passkeys/webauthn";

// Typed from the real export, so a mocked answer that does not match what the module promises is a
// failure here rather than an `any` flowing into the component under test.
const getAssertion = vi.fn<typeof realGetAssertion>();

// The whole assertion the ceremony serialises, so what the spec sends is what the form would.
const SERIALIZED_ASSERTION = {
  id: "credential-1",
  rawId: "AQID",
  type: "public-key",
  authenticatorAttachment: null,
  response: {
    clientDataJSON: "BAUG",
    authenticatorData: "BwgJ",
    signature: "CgsM",
    userHandle: null,
  },
  clientExtensionResults: {},
};
const passkeysSupported = vi.fn<() => boolean>(() => true);

vi.mock("@/features/auth/passkeys/webauthn", () => ({
  getAssertion: (options: unknown) => getAssertion(options),
  passkeysSupported: () => passkeysSupported(),
}));

import type { solveInvisibleTurnstile as realSolveInvisibleTurnstile } from "@/features/auth/turnstile/invisibleToken";

const solveInvisibleTurnstile = vi.fn<typeof realSolveInvisibleTurnstile>();

vi.mock("@/features/auth/turnstile/invisibleToken", () => ({
  solveInvisibleTurnstile: (...args: Parameters<typeof realSolveInvisibleTurnstile>) =>
    solveInvisibleTurnstile(...args),
}));

const { default: EmailSignInForm } = await import("@/features/auth/signin/EmailSignInForm");
const { default: EmailPassCodeForm } = await import("@/features/auth/signin/EmailPassCodeForm");
const { default: SecretSignInForm } = await import("@/features/auth/signin/SecretSignInForm");
const { default: TotpChallengeForm } = await import("@/features/auth/signin/TotpChallengeForm");
const { default: OtpResendButton } = await import("@/features/auth/signin/OtpResendButton");
const { default: PasskeySignInPanel } = await import("@/features/auth/signin/PasskeySignInPanel");
const { default: StepUpPasskeyScreen } = await import("@/features/auth/signin/StepUpPasskeyScreen");
const { csrfToken } = await import("@/features/auth/signin/csrf");
const { PASSKEY_MESSAGES } = await import("@/features/auth/passkeys/messages");

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

// React tracks the previous value of a controlled input, so assigning `value` directly is ignored.
// Going through the prototype setter clears that tracker, which is what a real keystroke does.
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
  });
};

declare global {
  // React reads this flag off the global object to decide whether `act` is allowed.
  var IS_REACT_ACT_ENVIRONMENT: boolean;
}

globalThis.IS_REACT_ACT_ENVIRONMENT = true;

// The production code only reads `status` and `json()`, but building a real Response keeps the stub
// assignable to `fetch` without asserting a hand-written object into the type.
const jsonResponse = (status: number, payload: unknown): Response =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { "content-type": "application/json" },
  });

const stubFetch = (status: number, payload: unknown) =>
  vi.stubGlobal(
    "fetch",
    vi.fn(async () => jsonResponse(status, payload)),
  );

const turnstile = { site_key: "site-key", mode: "render" as const, action: null, cdata: null };
const backLink = { label: "もどる", href: "/sign/in?ri=jp" };

/**
 * Stubs the Cloudflare script and its API so `TurnstileWidget` solves the challenge on the same
 * tick it renders, as a Turnstile deployment configured to auto-solve does.
 */
function stubTurnstileWidget() {
  document.head.innerHTML +=
    '<script src="https://challenges.cloudflare.com/turnstile/v0/api.js"></script>';
  vi.stubGlobal("turnstile", {
    render: vi.fn((_container: HTMLElement, options: { callback: (token: string) => void }) => {
      queueMicrotask(() => options.callback("solved-token"));
      return "widget-1";
    }),
    execute: vi.fn(),
    remove: vi.fn(),
  });
}

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="csrf-value">';
});

afterEach(() => {
  act(() => {
    root.unmount();
  });
  container.remove();
  document.head.innerHTML = "";
  vi.clearAllMocks();
  vi.useRealTimers();
});

describe("csrf token", () => {
  it("reads the token from the document rather than from a prop", () => {
    mount(<div />);

    expect(csrfToken()).toBe("csrf-value");

    document.head.innerHTML = "";

    expect(csrfToken()).toBe("");
  });
});

describe("email sign-in form interaction", () => {
  const props = {
    title: "メールでログイン",
    description: "免責事項",
    form: {
      action: "/sign/in/email",
      method: "post",
      pt: null,
      address_field: {
        scope: "client_email",
        field: "address",
        name: "client_email[address]",
        label: "メールアドレス",
        placeholder: "name@example.com",
      },
      submit_label: "送信する",
    },
    turnstile,
    form_errors: [],
    back_link: backLink,
  };

  it("keeps the verb the route expects and sends the address under its Rails wrapper", () => {
    mount(<EmailSignInForm {...props} />);

    type("input[type=email]", "someone@example.com");

    expect(setData).toHaveBeenCalledWith("client_email", { address: "someone@example.com" });

    act(() => {
      container
        .querySelector("form")
        ?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(post).toHaveBeenCalledWith("/sign/in/email");
  });

  it("forwards the solved Turnstile token", async () => {
    stubTurnstileWidget();
    mount(<EmailSignInForm {...props} />);

    await flush();

    expect(setData).toHaveBeenCalledWith("cf-turnstile-response", "solved-token");
    vi.unstubAllGlobals();
  });
});

describe("pass code form interaction", () => {
  const props = {
    title: "認証コード入力",
    description: "メールアドレスに届きます",
    form: {
      action: "/sign/in/email",
      method: "patch",
      pt: "signed-pt",
      pass_code_field: {
        scope: "client_email",
        field: "pass_code",
        name: "client_email[pass_code]",
        label: "認証コード",
        placeholder: "6桁の数字を入力",
        max_length: 6,
        autocomplete: "one-time-code",
        inputmode: "numeric" as const,
        pattern: "[0-9]*",
      },
      submit_label: "送信する",
    },
    otp_resend: {
      endpoint: "/web/v0/in/email/otp",
      state: "resend-state",
      button_label: "再送する",
      sent_message: "送信しました",
      too_soon_message: "しばらくお待ちください",
      failed_message: "失敗しました",
    },
    turnstile,
    form_errors: [],
    delivery_help: "届かない場合",
    back_link: backLink,
  };

  it("submits the code with PATCH, the verb the route expects", () => {
    mount(<EmailPassCodeForm {...props} />);

    type("input[type=text]", "123456");

    expect(setData).toHaveBeenCalledWith("client_email", { pass_code: "123456" });

    act(() => {
      container
        .querySelector("form")
        ?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(patch).toHaveBeenCalledWith("/sign/in/email");
  });

  it("clears the code field when the server confirms a resend", async () => {
    stubFetch(200, { resendable: true });

    mount(<EmailPassCodeForm {...props} />);
    click("button[type=button]");
    await flush();

    expect(setData).toHaveBeenCalledWith("client_email", { pass_code: "" });
    vi.unstubAllGlobals();
  });

  it("forwards the solved Turnstile token", async () => {
    stubTurnstileWidget();
    mount(<EmailPassCodeForm {...props} />);

    await flush();

    expect(setData).toHaveBeenCalledWith("cf-turnstile-response", "solved-token");
    vi.unstubAllGlobals();
  });
});

describe("secret sign-in form interaction", () => {
  const props = {
    title: "パスワードでログイン",
    form: {
      action: "/sign/in/secret",
      method: "post",
      pt: null,
      ri: "jp",
      identifier_field: {
        scope: "secret_credential_login_form",
        field: "identifier",
        name: "secret_credential_login_form[identifier]",
        label: "メールアドレスまたはID",
        placeholder: "someone@example.com",
      },
      secret_field: {
        scope: "secret_credential_login_form",
        field: "value",
        name: "secret_credential_login_form[value]",
        label: "パスワード",
        placeholder: "",
      },
      submit_label: "サインイン",
    },
    hints: null,
    error_heading: "エラー",
    form_errors: [],
    turnstile,
    back_link: backLink,
  };

  it("keeps the identifier and secret under the same Rails wrapper", () => {
    mount(<SecretSignInForm {...props} />);

    type("input[type=text]", "someone@example.com");
    expect(setData).toHaveBeenCalledWith("secret_credential_login_form", {
      identifier: "someone@example.com",
      value: "",
    });

    type("input[type=password]", "hunter2");
    expect(setData).toHaveBeenCalledWith("secret_credential_login_form", {
      identifier: "",
      value: "hunter2",
    });

    act(() => {
      container
        .querySelector("form")
        ?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(post).toHaveBeenCalledWith("/sign/in/secret");
  });

  it("lists the previous attempt's errors and forwards the solved Turnstile token", async () => {
    stubTurnstileWidget();
    mount(
      <SecretSignInForm
        {...props}
        form_errors={["資格情報が正しくありません"]}
      />,
    );

    expect(container.querySelectorAll("[role=alert] li")).toHaveLength(1);
    expect(container.querySelector("[role=alert]")?.textContent).toContain(
      "資格情報が正しくありません",
    );

    await flush();
    expect(setData).toHaveBeenCalledWith("cf-turnstile-response", "solved-token");
    vi.unstubAllGlobals();
  });

  it("omits the identifier field on the second-factor challenge and still submits the secret", () => {
    mount(
      <SecretSignInForm
        {...props}
        form={{
          ...props.form,
          identifier_field: null,
          secret_field: {
            ...props.form.secret_field,
            scope: "mfa_secret_credential_form",
            name: "mfa_secret_credential_form[value]",
          },
        }}
        hints={{ label: "サインイン中のアカウント", value: "someone@example.com" }}
      />,
    );

    expect(container.querySelector("input[type=text]")).toBeNull();

    type("input[type=password]", "hunter2");
    expect(setData).toHaveBeenCalledWith("mfa_secret_credential_form", { value: "hunter2" });

    act(() => {
      container
        .querySelector("form")
        ?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(post).toHaveBeenCalledWith("/sign/in/secret");
  });
});

describe("totp challenge form interaction", () => {
  const props = {
    title: "二段階認証",
    description: "認証アプリのコードを入力してください",
    form: {
      action: "/sign/in/challenge/totp",
      method: "post",
      token_field: {
        scope: "totp_challenge_form",
        field: "code",
        name: "totp_challenge_form[code]",
        label: "認証コード",
        placeholder: "123456",
        max_length: 6,
        inputmode: "numeric" as const,
        help: "6桁の数字です",
      },
      submit_label: "確認する",
    },
    error_heading: "エラー",
    form_errors: [],
    turnstile,
    back_link: backLink,
  };

  it("keeps the code under its own Rails wrapper and submits it", () => {
    mount(<TotpChallengeForm {...props} />);

    type("input[type=text]", "123456");
    expect(setData).toHaveBeenCalledWith("totp_challenge_form", { code: "123456" });

    act(() => {
      container
        .querySelector("form")
        ?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(post).toHaveBeenCalledWith("/sign/in/challenge/totp");
  });

  it("lists the previous attempt's errors and forwards the solved Turnstile token", async () => {
    stubTurnstileWidget();
    mount(
      <TotpChallengeForm
        {...props}
        form_errors={["認証コードが正しくありません"]}
      />,
    );

    expect(container.querySelectorAll("[role=alert] li")).toHaveLength(1);
    expect(container.querySelector("[role=alert]")?.textContent).toContain(
      "認証コードが正しくありません",
    );

    await flush();
    expect(setData).toHaveBeenCalledWith("cf-turnstile-response", "solved-token");
    vi.unstubAllGlobals();
  });
});

describe("otp resend button", () => {
  const resend = {
    endpoint: "/web/v0/in/email/otp",
    state: "resend-state",
    button_label: "再送する",
    sent_message: "送信しました",
    too_soon_message: "しばらくお待ちください",
    failed_message: "失敗しました",
  };

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("posts the resend state with the CSRF header and reports success", async () => {
    stubFetch(200, { resendable: true });
    const onResent = vi.fn();
    mount(
      <OtpResendButton
        resend={resend}
        onResent={onResent}
      />,
    );

    click("button");
    await flush();

    expect(onResent).toHaveBeenCalled();
    expect(container.querySelector("p")?.textContent).toBe("送信しました");
    const [, init] = present(vi.mocked(fetch).mock.calls[0], "the first fetch call");
    expect(present(init, "the request options")).toMatchObject({
      method: "POST",
      headers: containing({ "X-CSRF-Token": "csrf-value" }),
    });
  });

  it("counts down and blocks a second press while the server says it is too soon", async () => {
    vi.useFakeTimers();
    stubFetch(429, { retry_after: 2 });
    mount(
      <OtpResendButton
        resend={resend}
        onResent={vi.fn()}
      />,
    );

    click("button");
    await act(async () => {
      await Promise.resolve();
      await Promise.resolve();
    });

    const button = container.querySelector("button");

    expect(button?.disabled).toBe(true);
    expect(button?.textContent).toContain("(2s)");

    const fetchCallsBeforeSecondPress = vi.mocked(fetch).mock.calls.length;
    click("button");
    expect(vi.mocked(fetch).mock.calls).toHaveLength(fetchCallsBeforeSecondPress);

    act(() => {
      vi.advanceTimersByTime(1000);
    });

    expect(container.querySelector("button")?.textContent).toContain("(1s)");

    act(() => {
      vi.advanceTimersByTime(1000);
    });

    expect(container.querySelector("button")?.disabled).toBe(false);
  });

  it("resets immediately when the server reports no remaining wait", async () => {
    stubFetch(429, {});
    mount(
      <OtpResendButton
        resend={resend}
        onResent={vi.fn()}
      />,
    );

    click("button");
    await flush();

    expect(container.querySelector("button")?.disabled).toBe(false);
    expect(container.querySelector("p")?.textContent).toBe("しばらくお待ちください");
  });

  it("reports a failure for any other answer", async () => {
    stubFetch(500, {});
    mount(
      <OtpResendButton
        resend={resend}
        onResent={vi.fn()}
      />,
    );

    click("button");
    await flush();

    expect(container.querySelector("p")?.textContent).toBe("失敗しました");
  });

  it("reports a failure when the request itself cannot be made", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => {
        throw new Error("offline");
      }),
    );
    mount(
      <OtpResendButton
        resend={resend}
        onResent={vi.fn()}
      />,
    );

    click("button");
    await flush();

    expect(container.querySelector("p")?.textContent).toBe("失敗しました");
  });
});

describe("passkey sign-in panel", () => {
  const props = {
    options_url: "/sign/in/passkey/options?ri=jp",
    verification_url: "/sign/in/passkey/verification?ri=jp",
    region: "jp",
    identifier_param: "identifier",
    turnstile_site_key: "stealth-key",
    turnstile_error_message: "検証に失敗しました",
    field: { label: "メールアドレス", placeholder: "name@example.com" },
    submit_label: "パスキーでログイン",
  };

  const typeIdentifier = (value: string) => type("input#identifier", value);

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("refuses to start on a browser without WebAuthn", async () => {
    passkeysSupported.mockReturnValueOnce(false);
    mount(<PasskeySignInPanel {...props} />);
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(PASSKEY_MESSAGES.unsupported);
  });

  it("refuses to start without an identifier", async () => {
    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("   ");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      PASSKEY_MESSAGES.identifierRequired,
    );
  });

  it("carries the challenge token and the assertion to the server, then follows its redirect", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);

    const fetchMock = stubFetchQueue(
      httpJsonResponse({ challenge_id: "challenge-1", options: { a: 1 } }),
      httpJsonResponse({ status: "ok", redirect_url: "/identity" }),
    );
    const location = { href: "", reload: vi.fn() };
    vi.stubGlobal("location", location);

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(requestBody(fetchMock, 0)).toMatchObject({
      identifier: "someone@example.com",
      "cf-turnstile-response": "turnstile-token",
      ri: "jp",
    });
    expect(requestBody(fetchMock, 1)).toMatchObject({
      challenge_id: "challenge-1",
      credential: { id: "credential-1" },
    });
    expect(window.location.href).toBe("/identity");
  });

  it("follows the second-factor redirect the server asks for", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValueOnce({
          ok: true,
          headers: new Headers({ "content-type": "application/json" }),
          json: async () => ({ challenge_id: "c", options: {} }),
        })
        .mockResolvedValueOnce({
          ok: true,
          headers: new Headers({ "content-type": "application/json" }),
          json: async () => ({ status: "totp_required", redirect_url: "/challenge" }),
        }),
    );
    vi.stubGlobal("location", { href: "", reload: vi.fn() });

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(window.location.href).toBe("/challenge");
  });

  it("rejects an answer it does not recognise instead of assuming success", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValueOnce({
          ok: true,
          headers: new Headers({ "content-type": "application/json" }),
          json: async () => ({ challenge_id: "c", options: {} }),
        })
        .mockResolvedValueOnce({
          ok: true,
          headers: new Headers({ "content-type": "application/json" }),
          json: async () => ({ status: "surprise", redirect_url: "/nowhere" }),
        }),
    );
    vi.stubGlobal("location", { href: "", reload: vi.fn() });

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      PASSKEY_MESSAGES.unexpectedResponse,
    );
  });

  it("surfaces the server's own message when the options request is refused", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 422,
        headers: new Headers({ "content-type": "application/json" }),
        json: async () => ({ error: "識別子が必要です" }),
      }),
    );

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe("識別子が必要です");
  });

  it("falls back to its own copy when the server's error carries no message", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 422,
        headers: new Headers({ "content-type": "application/json" }),
        json: async () => ({}),
      }),
    );

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      PASSKEY_MESSAGES.optionsFailed,
    );
  });

  it("falls back to the default message when the surface sent none", async () => {
    solveInvisibleTurnstile.mockRejectedValue(
      new Error("Security verification failed. Please refresh and try again."),
    );

    mount(
      <PasskeySignInPanel
        {...props}
        turnstile_error_message=""
      />,
    );
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(solveInvisibleTurnstile).toHaveBeenCalledWith(
      "stealth-key",
      "Security verification failed. Please refresh and try again.",
      expect.anything(),
    );
  });

  it("omits the region from both requests when the surface carries none", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);
    const fetchMock = stubFetchQueue(
      httpJsonResponse({ challenge_id: "challenge-1", options: { a: 1 } }),
      httpJsonResponse({ status: "ok", redirect_url: "/identity" }),
    );
    vi.stubGlobal("location", { href: "", reload: vi.fn() });

    mount(
      <PasskeySignInPanel
        {...props}
        region=""
      />,
    );
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(requestBody(fetchMock, 0)).not.toHaveProperty("ri");
    expect(requestBody(fetchMock, 1)).not.toHaveProperty("ri");
  });

  it("falls back to its own copy for a failure with no content-type header at all", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(null, { status: 500 })));

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      "オプションの取得に失敗しました",
    );
  });

  it("fails loudly when the options response carries no challenge id", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        headers: new Headers({ "content-type": "application/json" }),
        json: async () => ({ options: {} }),
      }),
    );

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      PASSKEY_MESSAGES.optionsFailed,
    );
  });

  it("reloads when the session is gone rather than reporting a ceremony failure", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 401,
        headers: new Headers({ "content-type": "text/html" }),
        json: async () => ({}),
      }),
    );
    const reload = vi.fn();
    vi.stubGlobal("location", { href: "", reload });

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(reload).toHaveBeenCalled();
    expect(container.querySelector("[role=alert]")).toBeNull();
  });

  it("falls back to the ceremony message for a non-JSON refusal", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
        headers: new Headers({ "content-type": "text/html" }),
        json: async () => ({}),
      }),
    );

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      PASSKEY_MESSAGES.optionsFailed,
    );
  });

  it("reports a refused verification with the ceremony message", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValueOnce({
          ok: true,
          headers: new Headers({ "content-type": "application/json" }),
          json: async () => ({ challenge_id: "c", options: {} }),
        })
        .mockResolvedValueOnce({
          ok: false,
          status: 422,
          headers: new Headers({ "content-type": "text/html" }),
          json: async () => ({}),
        }),
    );

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      PASSKEY_MESSAGES.verificationFailed,
    );
  });

  it("reloads instead of continuing when the verification session is gone", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValueOnce({
          ok: true,
          headers: new Headers({ "content-type": "application/json" }),
          json: async () => ({ challenge_id: "c", options: {} }),
        })
        .mockResolvedValueOnce({
          ok: false,
          status: 302,
          headers: new Headers({ "content-type": "text/html" }),
          json: async () => ({}),
        }),
    );
    const reload = vi.fn();
    vi.stubGlobal("location", { href: "", reload });

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(reload).toHaveBeenCalled();
  });

  it("reports a challenge that could not be presented rather than proceeding without one", async () => {
    solveInvisibleTurnstile.mockRejectedValue(new Error("検証に失敗しました"));

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe("検証に失敗しました");
  });
});

describe("step-up passkey screen", () => {
  const props = {
    title: "パスキーで確認",
    description: "登録済みのパスキー",
    form: {
      action: "/sign/in/challenge/passkey",
      authenticity_token: "csrf-value",
      param_scope: "mfa_passkey_form",
      challenge_id: "challenge-1",
      request_options: { challenge: "abc" },
      submit_label: "認証する",
    },
    back_link: backLink,
  };

  it("refuses to start on a browser without WebAuthn", async () => {
    passkeysSupported.mockReturnValueOnce(false);
    mount(<StepUpPasskeyScreen {...props} />);
    click("button[type=button]");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(PASSKEY_MESSAGES.unsupported);
  });

  it("refuses to start when the server issued no challenge", async () => {
    mount(
      <StepUpPasskeyScreen
        {...props}
        form={{ ...props.form, request_options: null }}
      />,
    );
    click("button[type=button]");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      PASSKEY_MESSAGES.optionsMissing,
    );
  });

  it("puts the assertion in the form and submits it to the server", async () => {
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);
    const requestSubmit = vi.fn();
    HTMLFormElement.prototype.requestSubmit = requestSubmit;

    mount(<StepUpPasskeyScreen {...props} />);
    click("button[type=button]");
    await flush();

    const field = container.querySelector<HTMLInputElement>(
      'input[name="mfa_passkey_form[credential_json]"]',
    );

    expect(JSON.parse(present(field, "the credential field").value)).toMatchObject({
      id: "credential-1",
    });
    expect(requestSubmit).toHaveBeenCalled();
  });

  it("reports a cancelled ceremony instead of submitting", async () => {
    const cancelled = new Error("cancelled");
    cancelled.name = "NotAllowedError";
    getAssertion.mockRejectedValue(cancelled);

    mount(<StepUpPasskeyScreen {...props} />);
    click("button[type=button]");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(PASSKEY_MESSAGES.cancelled);
  });
});
