import { beforeEach, describe, expect, test, vi } from "vite-plus/test";

vi.mock("@hotwired/stimulus", () => ({
  Controller: class {
    constructor() {
      this.identifierTarget = { value: "" };
      this.errorTarget = { textContent: "", classList: { add: vi.fn(), remove: vi.fn() } };
      this.statusTarget = { textContent: "", classList: { add: vi.fn(), remove: vi.fn() } };
      this.turnstileResponseTarget = { value: "" };
      this.hasIdentifierTarget = true;
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

const { default: PasskeyAuthenticationController } =
  await import("../../src/controllers/passkey_authentication_controller.js");

describe("PasskeyAuthenticationController", () => {
  let controller;

  beforeEach(() => {
    controller = new PasskeyAuthenticationController();
    controller.optionsUrlValue = "/sign/in/passkeys/options";
    controller.verificationUrlValue = "/sign/in/passkeys/verification";
    controller.identifierParamValue = "email";
    controller.turnstileSiteKeyValue = "sitekey123";
    controller.turnstileErrorMessageValue =
      "Security verification failed. Please refresh and try again.";

    vi.stubGlobal("window", { PublicKeyCredential: true, location: { hostname: "localhost" } });
    vi.stubGlobal("navigator", { credentials: { get: vi.fn() } });
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
      })),
      head: { appendChild: vi.fn() },
    });
  });

  test("authenticate: WebAuthn 未対応時にエラーを表示する", async () => {
    window.PublicKeyCredential = false;

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("このブラウザはPasskeyに対応していません");
  });

  test("authenticate: 識別子が空の場合にエラーを表示する", async () => {
    controller.identifierTarget.value = "";

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("メールアドレスまたはIDを入力してください");
  });

  test("bufferToBase64url: ArrayBuffer を正しくエンコードする", () => {
    const { buffer } = new Uint8Array([1, 2, 3]);
    const result = controller.bufferToBase64url(buffer);
    expect(typeof result).toBe("string");
    expect(result).not.toContain("+");
    expect(result).not.toContain("/");
    expect(result).not.toContain("=");
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

  test("encodeCredential: 正しくエンコードする", () => {
    const credential = {
      id: "cred-id",
      rawId: new Uint8Array([1, 2, 3]).buffer,
      type: "public-key",
      authenticatorAttachment: "platform",
      response: {
        clientDataJSON: new Uint8Array([4, 5, 6]).buffer,
        authenticatorData: new Uint8Array([7, 8, 9]).buffer,
        signature: new Uint8Array([10, 11, 12]).buffer,
        userHandle: new Uint8Array([13, 14, 15]).buffer,
      },
      getClientExtensionResults: () => ({ appid: true }),
    };

    const result = controller.encodeCredential(credential);
    expect(result.id).toBe("cred-id");
    expect(result.type).toBe("public-key");
    expect(result.authenticatorAttachment).toBe("platform");
    expect(result.response.clientDataJSON).toBeDefined();
    expect(result.response.authenticatorData).toBeDefined();
    expect(result.response.signature).toBeDefined();
    expect(result.response.userHandle).toBeDefined();
    expect(result.clientExtensionResults).toEqual({ appid: true });
  });

  test("encodeCredential: authenticatorAttachment が null/undefined の場合", () => {
    const credential = {
      id: "cred-id",
      rawId: new Uint8Array([1]).buffer,
      type: "public-key",
      authenticatorAttachment: null,
      response: {
        clientDataJSON: new Uint8Array([4]).buffer,
        authenticatorData: new Uint8Array([7]).buffer,
        signature: new Uint8Array([10]).buffer,
        userHandle: null,
      },
      getClientExtensionResults: () => ({}),
    };

    const result = controller.encodeCredential(credential);
    expect(result.authenticatorAttachment).toBeNull();
    expect(result.response.userHandle).toBeNull();
  });

  test("ensureTurnstileToken: turnstileSiteKeyValue がなければエラー", async () => {
    controller.turnstileSiteKeyValue = "";

    await expect(controller.ensureTurnstileToken()).rejects.toThrow();
  });

  test("csrfToken: meta タグからトークンを取得する", () => {
    const result = controller.csrfToken;
    expect(result).toBe("csrf-token-value");
  });

  test("csrfToken: meta タグがない場合は空文字列", () => {
    const origDocument = globalThis.document;
    const querySelector = vi.fn(() => null);
    globalThis.document = {
      querySelector,
      createElement: vi.fn(),
      head: { appendChild: vi.fn() },
    };
    const result = controller.csrfToken;
    expect(result).toBe("");
    expect(querySelector).toHaveBeenCalledWith('meta[name="csrf-token"]');
    globalThis.document = origDocument;
  });

  test("identifierValue: target があればその値を返す", () => {
    controller.identifierTarget.value = "test@example.com";
    expect(controller.identifierValue).toBe("test@example.com");
  });

  test("identifierValue: target がなければ空文字列を返す", () => {
    controller.hasIdentifierTarget = false;
    expect(controller.identifierValue).toBe("");
  });

  test("authenticate: 成功時に verification まで完了する", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    const verificationResponse = {
      ok: true,
      json: () => Promise.resolve({ status: "ok", redirect_url: "/dashboard" }),
    };

    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce(optionsResponse).mockResolvedValueOnce(verificationResponse),
    );

    const mockCredential = {
      id: "cred-id",
      rawId: new Uint8Array([1, 2, 3]).buffer,
      type: "public-key",
      response: {
        clientDataJSON: new Uint8Array([4, 5, 6]).buffer,
        authenticatorData: new Uint8Array([7, 8, 9]).buffer,
        signature: new Uint8Array([10, 11, 12]).buffer,
        userHandle: null,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.get.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.statusTarget.textContent).toBe("ログイン成功！リダイレクト中...");
  });

  test("authenticate: TOTP 必要時にリダイレクトする", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    const verificationResponse = {
      ok: true,
      json: () => Promise.resolve({ status: "totp_required", redirect_url: "/totp" }),
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
        authenticatorData: new Uint8Array([7]).buffer,
        signature: new Uint8Array([10]).buffer,
        userHandle: null,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.get.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.statusTarget.textContent).toBe("二段階認証が必要です...");
  });

  test("authenticate: optionsResponse JSON で data.error が空", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

    const optionsResponse = {
      ok: false,
      status: 400,
      headers: { get: vi.fn(() => "application/json") },
      json: () => Promise.resolve({ error: "" }),
    };

    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(optionsResponse));

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("オプションの取得に失敗しました");
  });

  test("authenticate: optionsResponse が失敗し JSON エラーを返す", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

    const optionsResponse = {
      ok: false,
      status: 400,
      headers: { get: vi.fn(() => "application/json") },
      json: () => Promise.resolve({ error: "Invalid request" }),
    };

    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(optionsResponse));

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("Invalid request");
  });

  test("authenticate: optionsResponse が 401 のときページをリロードする", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

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
    await controller.authenticate(event);

    expect(reloadMock).toHaveBeenCalled();
  });

  test("authenticate: optionsResponse が non-JSON non-401/302 でエラー (content-type null)", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

    const optionsResponse = {
      ok: false,
      status: 500,
      headers: { get: vi.fn(() => null) },
    };

    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(optionsResponse));

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("オプションの取得に失敗しました");
  });

  test("authenticate: optionsResponse が非 JSON 非 401/302 でエラー", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

    const optionsResponse = {
      ok: false,
      status: 500,
      headers: { get: vi.fn(() => "text/html") },
    };

    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(optionsResponse));

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("オプションの取得に失敗しました");
  });

  test("authenticate: verificationResponse が 401 のときページをリロードする", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

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
        authenticatorData: new Uint8Array([7]).buffer,
        signature: new Uint8Array([10]).buffer,
        userHandle: null,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.get.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(reloadMock).toHaveBeenCalled();
  });

  test("authenticate: verificationResponse が JSON で data.error が空", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

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
        authenticatorData: new Uint8Array([7]).buffer,
        signature: new Uint8Array([10]).buffer,
        userHandle: null,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.get.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("認証に失敗しました");
  });

  test("authenticate: verificationResponse が non-JSON non-401/302 でエラー (content-type null)", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

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
        authenticatorData: new Uint8Array([7]).buffer,
        signature: new Uint8Array([10]).buffer,
        userHandle: null,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.get.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("認証に失敗しました");
  });

  test("authenticate: verificationResponse が非 JSON 非 401/302 でエラー", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

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
        authenticatorData: new Uint8Array([7]).buffer,
        signature: new Uint8Array([10]).buffer,
        userHandle: null,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.get.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("認証に失敗しました");
  });

  test("authenticate: verificationResponse が失敗し JSON エラーを返す", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

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
        authenticatorData: new Uint8Array([7]).buffer,
        signature: new Uint8Array([10]).buffer,
        userHandle: null,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.get.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("Verification failed");
  });

  test("authenticate: NotAllowedError のときに適切なエラーメッセージを表示する", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(optionsResponse));

    const error = new Error("Cancelled");
    error.name = "NotAllowedError";
    navigator.credentials.get.mockRejectedValue(error);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("認証がキャンセルされました");
  });

  test("authenticate: SecurityError のときに適切なエラーメッセージを表示する", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(optionsResponse));

    const error = new Error("Security issue");
    error.name = "SecurityError";
    navigator.credentials.get.mockRejectedValue(error);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("セキュリティエラーが発生しました");
  });

  test("authenticate: error.message が空のときデフォルトメッセージを表示する", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(optionsResponse));

    const error = new Error();
    error.name = "GenericError";
    navigator.credentials.get.mockRejectedValue(error);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("認証中にエラーが発生しました");
  });

  test("authenticate: 予期しない応答のときにエラーを表示する", async () => {
    controller.identifierTarget.value = "test@example.com";
    controller.turnstileResponseTarget.value = "turnstile-token";

    const optionsResponse = {
      ok: true,
      json: () => Promise.resolve({ challenge_id: "ch-1", options: {} }),
    };
    const verificationResponse = { ok: true, json: () => Promise.resolve({ status: "unknown" }) };

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
        authenticatorData: new Uint8Array([7]).buffer,
        signature: new Uint8Array([10]).buffer,
        userHandle: null,
      },
      getClientExtensionResults: () => ({}),
    };
    navigator.credentials.get.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("予期しない応答です");
  });

  test("ensureTurnstileToken: turnstileResponseTarget の値を返す", async () => {
    controller.turnstileResponseTarget.value = "existing-token";
    const result = await controller.ensureTurnstileToken();
    expect(result).toBe("existing-token");
  });

  test("ensureTurnstileToken: turnstileResponseTarget が空のときスクリプト読み込みを行う", async () => {
    controller.turnstileResponseTarget.value = "";
    const script = {
      src: "",
      async: true,
      defer: true,
      onload: null,
      onerror: null,
    };
    const container = { style: {} };
    vi.stubGlobal("document", {
      querySelector: vi.fn(() => null),
      createElement: vi.fn().mockReturnValueOnce(script).mockReturnValueOnce(container),
      head: { appendChild: vi.fn() },
    });

    const promise = controller.ensureTurnstileToken();
    window.turnstile = {
      render: vi.fn((_container, options) => {
        options.callback("new-token");
      }),
    };
    script.onload();
    const result = await promise;
    expect(result).toBe("new-token");
    expect(controller.turnstileResponseTarget.value).toBe("new-token");
  });

  test("ensureTurnstileScriptLoaded: 既に window.turnstile があるときすぐ解決する", async () => {
    vi.stubGlobal("window", {
      PublicKeyCredential: true,
      turnstile: true,
      location: { hostname: "localhost" },
    });
    await expect(controller.ensureTurnstileScriptLoaded()).resolves.toBeUndefined();
  });

  test("ensureTurnstileScriptLoaded: 既存スクリプトの load イベントで解決する", async () => {
    vi.stubGlobal("window", { PublicKeyCredential: true, location: { hostname: "localhost" } });
    const existingScript = { addEventListener: vi.fn() };
    vi.stubGlobal("document", {
      querySelector: vi.fn(() => existingScript),
      createElement: vi.fn(),
      head: { appendChild: vi.fn() },
    });

    const promise = controller.ensureTurnstileScriptLoaded();
    const [, loadCallback] = existingScript.addEventListener.mock.calls.find(
      ([event]) => event === "load",
    );
    loadCallback();
    await expect(promise).resolves.toBeUndefined();
  });

  test("ensureTurnstileScriptLoaded: 既存スクリプトの error で拒否する", async () => {
    vi.stubGlobal("window", { PublicKeyCredential: true, location: { hostname: "localhost" } });
    const existingScript = { addEventListener: vi.fn() };
    vi.stubGlobal("document", {
      querySelector: vi.fn(() => existingScript),
      createElement: vi.fn(),
      head: { appendChild: vi.fn() },
    });

    const promise = controller.ensureTurnstileScriptLoaded();
    const [, errorCallback] = existingScript.addEventListener.mock.calls.find(
      ([event]) => event === "error",
    );
    errorCallback();
    await expect(promise).rejects.toThrow();
  });

  test("ensureTurnstileScriptLoaded: 新規スクリプトの load イベントで解決する", async () => {
    vi.stubGlobal("window", { PublicKeyCredential: true, location: { hostname: "localhost" } });
    const script = {
      src: "",
      async: true,
      defer: true,
      onload: null,
      onerror: null,
    };
    vi.stubGlobal("document", {
      querySelector: vi.fn(() => null),
      createElement: vi.fn(() => script),
      head: { appendChild: vi.fn() },
    });

    const promise = controller.ensureTurnstileScriptLoaded();
    expect(script.onload).not.toBeNull();
    script.onload();
    await expect(promise).resolves.toBeUndefined();
  });

  test("ensureTurnstileScriptLoaded: 新規スクリプトの error で拒否する", async () => {
    vi.stubGlobal("window", { PublicKeyCredential: true, location: { hostname: "localhost" } });
    const script = {
      src: "",
      async: true,
      defer: true,
      onload: null,
      onerror: null,
    };
    vi.stubGlobal("document", {
      querySelector: vi.fn(() => null),
      createElement: vi.fn(() => script),
      head: { appendChild: vi.fn() },
    });

    const promise = controller.ensureTurnstileScriptLoaded();
    expect(script.onerror).not.toBeNull();
    script.onerror();
    await expect(promise).rejects.toThrow();
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

  test("requestTurnstileToken: callback で turnstileResponseTarget がないときも解決する", async () => {
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

  test("showError: statusTarget がない場合もエラーを表示する", () => {
    controller.hasStatusTarget = false;
    controller.showError("test error");
    expect(controller.errorTarget.textContent).toBe("test error");
  });

  test("showStatus: statusTarget がないときは何もしない", () => {
    controller.hasStatusTarget = false;
    controller.showStatus("test status");
    expect(controller.statusTarget.textContent).toBe("");
  });

  test("clearMessages: errorTarget がない場合も status をクリアする", () => {
    controller.hasErrorTarget = false;
    controller.clearMessages();
    expect(controller.statusTarget.textContent).toBe("");
    expect(controller.statusTarget.classList.add).toHaveBeenCalledWith("hidden");
  });

  test("clearMessages: statusTarget がない場合も error をクリアする", () => {
    controller.hasStatusTarget = false;
    controller.clearMessages();
    expect(controller.errorTarget.textContent).toBe("");
    expect(controller.errorTarget.classList.add).toHaveBeenCalledWith("hidden");
  });

  test("csrfToken: meta タグがない場合は空文字列を返す", () => {
    vi.stubGlobal("document", {
      querySelector: vi.fn(() => null),
      createElement: vi.fn(),
      head: { appendChild: vi.fn() },
    });
    expect(controller.csrfToken).toBe("");
  });
});
