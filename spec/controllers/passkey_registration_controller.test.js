import { beforeEach, describe, expect, test, vi } from "vite-plus/test";

vi.mock("@hotwired/stimulus", () => ({
  Controller: class {
    constructor() {
      this.descriptionTarget = { value: "" };
      this.errorTarget = { textContent: "", classList: { add: vi.fn(), remove: vi.fn() } };
      this.statusTarget = { textContent: "", classList: { add: vi.fn(), remove: vi.fn() } };
      this.turnstileResponseTarget = { value: "" };
      this.hasDescriptionTarget = true;
      this.hasErrorTarget = true;
      this.hasStatusTarget = true;
      this.hasTurnstileResponseTarget = true;
      this.element = { appendChild: vi.fn() };
    }

    connect() {}

    dispatch() {}
  },
}));

vi.mock("../../src/controllers/webauthn_utils.js", () => ({
  normalizePublicKeyOptions: vi.fn((opt) => opt),
}));

const { default: PasskeyRegistrationController } =
  await import("../../src/controllers/passkey_registration_controller.js");

describe("PasskeyRegistrationController", () => {
  let controller;

  beforeEach(() => {
    controller = new PasskeyRegistrationController();
    controller.optionsUrlValue = "/settings/passkeys/options";
    controller.verificationUrlValue = "/settings/passkeys/verification";
    controller.beginUrlValue = "/settings/passkeys/begin";
    controller.finishUrlValue = "/settings/passkeys/finish";
    controller.successRedirectUrlValue = "/settings";
    controller.turnstileSiteKeyValue = "sitekey123";
    controller.turnstileResponseTarget.value = "turnstile-token";
    controller.hasBeginUrlValue = true;
    controller.hasFinishUrlValue = true;
    controller.hasSuccessRedirectUrlValue = true;

    vi.stubGlobal("window", { PublicKeyCredential: true, location: { hostname: "localhost" } });
    vi.stubGlobal("navigator", { credentials: { create: vi.fn() } });
    vi.stubGlobal("fetch", vi.fn());
    vi.stubGlobal("btoa", (str) => Buffer.from(str, "binary").toString("base64"));
    vi.stubGlobal("document", {
      querySelector: vi.fn((selector) => {
        if (selector.includes("csrf-token")) {
          return { content: "csrf-token-value" };
        }
        return null;
      }),
      createElement: vi.fn(() => ({
        src: "",
        async: true,
        defer: true,
        onload: null,
        onerror: null,
        appendChild: vi.fn(),
        style: {},
      })),
      head: { appendChild: vi.fn() },
    });
  });

  test("register: WebAuthn 未対応時にエラーを表示する", async () => {
    window.PublicKeyCredential = false;

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(controller.errorTarget.textContent).toBe("このブラウザはPasskeyに対応していません");
  });

  test("bufferToBase64url: ArrayBuffer を正しくエンコードする", () => {
    const { buffer } = new Uint8Array([1, 2, 3]);
    const result = controller.bufferToBase64url(buffer);
    expect(typeof result).toBe("string");
    expect(result).not.toContain("+");
    expect(result).not.toContain("/");
    expect(result).not.toContain("=");
  });

  test("encodeCredential: 正しくエンコードする", () => {
    const credential = {
      id: "cred-id",
      rawId: new Uint8Array([1, 2, 3]).buffer,
      type: "public-key",
      authenticatorAttachment: "platform",
      response: {
        clientDataJSON: new Uint8Array([4, 5, 6]).buffer,
        attestationObject: new Uint8Array([7, 8, 9]).buffer,
      },
      getClientExtensionResults: () => ({ appid: true }),
    };

    const result = controller.encodeCredential(credential);
    expect(result.id).toBe("cred-id");
    expect(result.type).toBe("public-key");
    expect(result.authenticatorAttachment).toBe("platform");
    expect(result.response.clientDataJSON).toBeDefined();
    expect(result.response.attestationObject).toBeDefined();
    expect(result.clientExtensionResults).toEqual({ appid: true });
  });

  test("showError: エラーメッセージを表示する", () => {
    controller.showError("Error message");
    expect(controller.errorTarget.textContent).toBe("Error message");
    expect(controller.errorTarget.classList.remove).toHaveBeenCalledWith("hidden");
  });

  test("showStatus: ステータスメッセージを表示する", () => {
    controller.showStatus("Status message");
    expect(controller.statusTarget.textContent).toBe("Status message");
    expect(controller.statusTarget.classList.remove).toHaveBeenCalledWith("hidden");
  });

  test("clearMessages: メッセージをクリアする", () => {
    controller.clearMessages();
    expect(controller.errorTarget.textContent).toBe("");
    expect(controller.errorTarget.classList.add).toHaveBeenCalledWith("hidden");
    expect(controller.statusTarget.textContent).toBe("");
    expect(controller.statusTarget.classList.add).toHaveBeenCalledWith("hidden");
  });

  test("descriptionValue: target があればその値を返す", () => {
    controller.descriptionTarget.value = "My Passkey";
    expect(controller.descriptionValue).toBe("My Passkey");
  });

  test("descriptionValue: target がなければ空文字列を返す", () => {
    controller.hasDescriptionTarget = false;
    expect(controller.descriptionValue).toBe("");
  });

  test("csrfToken: meta タグからトークンを取得する", () => {
    const result = controller.csrfToken;
    expect(result).toBe("csrf-token-value");
  });

  test("csrfToken: meta タグがない場合は空文字列を返す", () => {
    vi.stubGlobal("document", {
      querySelector: vi.fn(() => null),
      createElement: vi.fn(),
      head: { appendChild: vi.fn() },
    });
    expect(controller.csrfToken).toBe("");
  });

  test("requestBeginUrl: beginUrlValue を優先する", () => {
    controller.beginUrlValue = "/custom/begin";
    expect(controller.requestBeginUrl).toBe("/custom/begin");
  });

  test("requestBeginUrl: beginUrlValue がなければ optionsUrlValue を使う", () => {
    controller.hasBeginUrlValue = false;
    expect(controller.requestBeginUrl).toBe("/settings/passkeys/options");
  });

  test("requestFinishUrl: finishUrlValue を優先する", () => {
    controller.finishUrlValue = "/custom/finish";
    expect(controller.requestFinishUrl).toBe("/custom/finish");
  });

  test("requestFinishUrl: finishUrlValue がなければ verificationUrlValue を使う", () => {
    controller.hasFinishUrlValue = false;
    expect(controller.requestFinishUrl).toBe("/settings/passkeys/verification");
  });

  test("redirectUrl: successRedirectUrlValue を優先する", () => {
    expect(controller.redirectUrl).toBe("/settings");
  });

  test("redirectUrl: 値がなければ空文字列", () => {
    controller.hasSuccessRedirectUrlValue = false;
    expect(controller.redirectUrl).toBe("");
  });

  test("register: 成功時にリダイレクトする", async () => {
    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    const verificationResponse = {
      ok: true,
      json: () => Promise.resolve({ redirect_url: "/settings" }),
    };

    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce(optionsResponse).mockResolvedValueOnce(verificationResponse),
    );

    const mockCredential = {
      id: "cred-id",
      rawId: new Uint8Array([1, 2, 3]).buffer,
      type: "public-key",
      authenticatorAttachment: "platform",
      response: {
        clientDataJSON: new Uint8Array([4, 5, 6]).buffer,
        attestationObject: new Uint8Array([7, 8, 9]).buffer,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.create.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(controller.statusTarget.textContent).toBe("登録完了！リダイレクト中...");
  });

  test("register: optionsResponse JSON で data.error が空", async () => {
    const optionsResponse = {
      ok: false,
      status: 400,
      headers: { get: vi.fn(() => "application/json") },
      json: () => Promise.resolve({ error: "" }),
    };

    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(optionsResponse));

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(controller.errorTarget.textContent).toBe("オプションの取得に失敗しました");
  });

  test("register: optionsResponse が失敗し JSON エラーを返す", async () => {
    const optionsResponse = {
      ok: false,
      status: 400,
      headers: { get: vi.fn(() => "application/json") },
      json: () => Promise.resolve({ error: "Invalid request" }),
    };

    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(optionsResponse));

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(controller.errorTarget.textContent).toBe("Invalid request");
  });

  test("register: optionsResponse が non-JSON non-401/302 でエラー (content-type null)", async () => {
    const optionsResponse = {
      ok: false,
      status: 500,
      headers: { get: vi.fn(() => null) },
    };

    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(optionsResponse));

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(controller.errorTarget.textContent).toBe("オプションの取得に失敗しました");
  });

  test("register: optionsResponse が非 JSON 非 401/302 でエラー", async () => {
    const optionsResponse = {
      ok: false,
      status: 500,
      headers: { get: vi.fn(() => "text/html") },
    };

    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(optionsResponse));

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(controller.errorTarget.textContent).toBe("オプションの取得に失敗しました");
  });

  test("register: optionsResponse が 401 のときページをリロードする", async () => {
    const reloadMock = vi.fn();
    vi.stubGlobal("window", {
      PublicKeyCredential: true,
      location: { hostname: "localhost", reload: reloadMock },
    });

    const optionsResponse = {
      ok: false,
      status: 401,
      headers: { get: vi.fn(() => "text/html") },
    };

    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(optionsResponse));

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(reloadMock).toHaveBeenCalled();
  });

  test("register: verificationResponse が失敗し JSON エラーを返す", async () => {
    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    const verificationResponse = {
      ok: false,
      status: 400,
      headers: { get: vi.fn(() => "application/json") },
      json: () => Promise.resolve({ error: "Verification failed" }),
    };

    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce(optionsResponse).mockResolvedValueOnce(verificationResponse),
    );

    const mockCredential = {
      id: "cred-id",
      rawId: new Uint8Array([1]).buffer,
      type: "public-key",
      response: {
        clientDataJSON: new Uint8Array([4]).buffer,
        attestationObject: new Uint8Array([7]).buffer,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.create.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(controller.errorTarget.textContent).toBe("Verification failed");
  });

  test("register: verificationResponse が non-JSON non-401/302 でエラー (content-type null)", async () => {
    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    const verificationResponse = {
      ok: false,
      status: 500,
      headers: { get: vi.fn(() => null) },
    };

    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce(optionsResponse).mockResolvedValueOnce(verificationResponse),
    );

    const mockCredential = {
      id: "cred-id",
      rawId: new Uint8Array([1]).buffer,
      type: "public-key",
      response: {
        clientDataJSON: new Uint8Array([4]).buffer,
        attestationObject: new Uint8Array([7]).buffer,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.create.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(controller.errorTarget.textContent).toBe("登録に失敗しました");
  });

  test("register: verificationResponse が非 JSON 非 401/302 でエラー", async () => {
    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    const verificationResponse = {
      ok: false,
      status: 500,
      headers: { get: vi.fn(() => "text/html") },
    };

    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce(optionsResponse).mockResolvedValueOnce(verificationResponse),
    );

    const mockCredential = {
      id: "cred-id",
      rawId: new Uint8Array([1]).buffer,
      type: "public-key",
      response: {
        clientDataJSON: new Uint8Array([4]).buffer,
        attestationObject: new Uint8Array([7]).buffer,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.create.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(controller.errorTarget.textContent).toBe("登録に失敗しました");
  });

  test("register: verificationResponse JSON で data.error が空のときデフォルトメッセージ", async () => {
    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    const verificationResponse = {
      ok: false,
      status: 400,
      headers: { get: vi.fn(() => "application/json") },
      json: () => Promise.resolve({ error: "" }),
    };

    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce(optionsResponse).mockResolvedValueOnce(verificationResponse),
    );

    const mockCredential = {
      id: "cred-id",
      rawId: new Uint8Array([1]).buffer,
      type: "public-key",
      response: {
        clientDataJSON: new Uint8Array([4]).buffer,
        attestationObject: new Uint8Array([7]).buffer,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.create.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(controller.errorTarget.textContent).toBe("登録に失敗しました");
  });

  test("register: verificationResponse が 401 のときページをリロードする", async () => {
    const reloadMock = vi.fn();
    vi.stubGlobal("window", {
      PublicKeyCredential: true,
      location: { hostname: "localhost", reload: reloadMock },
    });

    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    const verificationResponse = {
      ok: false,
      status: 401,
      headers: { get: vi.fn(() => "text/html") },
    };

    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce(optionsResponse).mockResolvedValueOnce(verificationResponse),
    );

    const mockCredential = {
      id: "cred-id",
      rawId: new Uint8Array([1]).buffer,
      type: "public-key",
      response: {
        clientDataJSON: new Uint8Array([4]).buffer,
        attestationObject: new Uint8Array([7]).buffer,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.create.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(reloadMock).toHaveBeenCalled();
  });

  test("register: NotAllowedError のときに適切なエラーメッセージを表示する", async () => {
    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(optionsResponse));

    const error = new Error("Cancelled");
    error.name = "NotAllowedError";
    navigator.credentials.create.mockRejectedValue(error);

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(controller.errorTarget.textContent).toBe("認証がキャンセルされました");
  });

  test("register: InvalidStateError のときに適切なエラーメッセージを表示する", async () => {
    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(optionsResponse));

    const error = new Error("Already registered");
    error.name = "InvalidStateError";
    navigator.credentials.create.mockRejectedValue(error);

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(controller.errorTarget.textContent).toBe("このPasskeyは既に登録されています");
  });

  test("register: checkpoint_version を含めて送信する", async () => {
    controller.hasCheckpointVersionValue = true;
    controller.checkpointVersionValue = "1.0";

    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    const verificationResponse = {
      ok: true,
      json: () => Promise.resolve({ redirect_url: "/done" }),
    };

    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce(optionsResponse).mockResolvedValueOnce(verificationResponse),
    );

    const mockCredential = {
      id: "cred-id",
      rawId: new Uint8Array([1]).buffer,
      type: "public-key",
      response: {
        clientDataJSON: new Uint8Array([4]).buffer,
        attestationObject: new Uint8Array([7]).buffer,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.create.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(fetch).toHaveBeenNthCalledWith(
      2,
      controller.requestFinishUrl,
      expect.objectContaining({
        body: expect.stringContaining("checkpoint_version"),
      }),
    );
    const body = JSON.parse(fetch.mock.calls[1][1].body);
    expect(body.checkpoint_version).toBe("1.0");
  });

  test("register: error.message が空のときデフォルトメッセージを表示する", async () => {
    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(optionsResponse));

    const error = new Error();
    error.name = "GenericError";
    navigator.credentials.create.mockRejectedValue(error);

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(controller.errorTarget.textContent).toBe("登録中にエラーが発生しました");
  });

  test("register: redirect_url がないとき successRedirectUrlValue にリダイレクトする", async () => {
    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    const verificationResponse = { ok: true, json: () => Promise.resolve({}) };

    const locationMock = { hostname: "localhost", href: "" };
    vi.stubGlobal("window", {
      PublicKeyCredential: true,
      location: locationMock,
    });

    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce(optionsResponse).mockResolvedValueOnce(verificationResponse),
    );

    const mockCredential = {
      id: "cred-id",
      rawId: new Uint8Array([1]).buffer,
      type: "public-key",
      response: {
        clientDataJSON: new Uint8Array([4]).buffer,
        attestationObject: new Uint8Array([7]).buffer,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.create.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(locationMock.href).toBe("/settings");
  });

  test("register: redirect_url がなく successRedirectUrlValue もないとき reload する", async () => {
    controller.hasSuccessRedirectUrlValue = false;

    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    const verificationResponse = { ok: true, json: () => Promise.resolve({}) };

    const reloadMock = vi.fn();
    vi.stubGlobal("window", {
      PublicKeyCredential: true,
      location: { hostname: "localhost", reload: reloadMock },
    });

    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce(optionsResponse).mockResolvedValueOnce(verificationResponse),
    );

    const mockCredential = {
      id: "cred-id",
      rawId: new Uint8Array([1]).buffer,
      type: "public-key",
      response: {
        clientDataJSON: new Uint8Array([4]).buffer,
        attestationObject: new Uint8Array([7]).buffer,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.create.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.register(event);

    expect(reloadMock).toHaveBeenCalled();
  });

  test("ensureTurnstileToken: layout script load後にtokenを取得する", async () => {
    controller.turnstileResponseTarget.value = "";
    const container = { style: {} };
    const existingScript = { addEventListener: vi.fn(), removeEventListener: vi.fn() };
    vi.stubGlobal("window", {
      PublicKeyCredential: true,
      location: { hostname: "localhost" },
      setTimeout: globalThis.setTimeout,
      clearTimeout: globalThis.clearTimeout,
    });
    const csrfToken = { content: "csrf-token-value" };
    vi.stubGlobal("document", {
      querySelector: vi.fn().mockReturnValueOnce(csrfToken).mockReturnValueOnce(existingScript),
      createElement: vi.fn(() => container),
      head: { appendChild: vi.fn() },
    });
    const promise = controller.ensureTurnstileToken();
    window.turnstile = {
      render: vi.fn((_container, options) => {
        options.callback("new-token");
      }),
    };
    const [, loadCallback] = existingScript.addEventListener.mock.calls.find(
      ([event]) => event === "load",
    );
    loadCallback();
    const result = await promise;
    expect(result).toBe("new-token");
    expect(controller.turnstileResponseTarget.value).toBe("new-token");
    expect(document.head.appendChild).not.toHaveBeenCalled();
  });

  test("ensureTurnstileToken: turnstileSiteKeyValue がなければエラー", async () => {
    controller.turnstileSiteKeyValue = "";
    await expect(controller.ensureTurnstileToken()).rejects.toThrow();
  });

  test("requestTurnstileToken: callback で turnstileResponseTarget がないときも解決する (reg)", async () => {
    controller.hasTurnstileResponseTarget = false;
    vi.stubGlobal("document", {
      createElement: vi.fn(() => ({ style: {}, appendChild: vi.fn() })),
    });
    window.turnstile = {
      render: vi.fn((_container, options) => {
        options.callback("token");
      }),
    };

    const result = await controller.requestTurnstileToken();
    expect(result).toBe("token");
  });

  test("requestTurnstileToken: error-callback で拒否する", async () => {
    vi.stubGlobal("document", {
      createElement: vi.fn(() => ({ style: {}, appendChild: vi.fn() })),
    });
    window.turnstile = {
      render: vi.fn((_container, options) => {
        options["error-callback"]();
      }),
    };

    await expect(controller.requestTurnstileToken()).rejects.toThrow();
  });

  test("requestTurnstileToken: expired-callback で拒否する", async () => {
    vi.stubGlobal("document", {
      createElement: vi.fn(() => ({ style: {}, appendChild: vi.fn() })),
    });
    window.turnstile = {
      render: vi.fn((_container, options) => {
        options["expired-callback"]();
      }),
    };

    await expect(controller.requestTurnstileToken()).rejects.toThrow();
  });

  test("requestTurnstileToken: turnstile がないとき catch で拒否する", async () => {
    controller.hasTurnstileResponseTarget = false;
    vi.stubGlobal("document", {
      createElement: vi.fn(() => ({ style: {}, appendChild: vi.fn() })),
    });
    window.turnstile = undefined;
    await expect(controller.requestTurnstileToken()).rejects.toThrow();
  });

  test("showError: errorTarget がないときは何もしない", () => {
    controller.hasErrorTarget = false;
    controller.showError("test error");
    expect(controller.errorTarget.textContent).toBe("");
  });

  test("showError: statusTarget がないときは何もしない", () => {
    controller.hasStatusTarget = false;
    controller.showError("test error");
    expect(controller.statusTarget.textContent).toBe("");
  });

  test("showStatus: statusTarget がないときは何もしない", () => {
    controller.hasStatusTarget = false;
    controller.showStatus("test status");
    expect(controller.statusTarget.textContent).toBe("");
  });

  test("clearMessages: errorTarget がないとき", () => {
    controller.hasErrorTarget = false;
    controller.clearMessages();
    expect(controller.statusTarget.textContent).toBe("");
  });

  test("clearMessages: statusTarget がないとき", () => {
    controller.hasStatusTarget = false;
    controller.clearMessages();
    expect(controller.errorTarget.textContent).toBe("");
  });
});
