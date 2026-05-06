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

vi.mock("controllers/webauthn_utils", () => ({
  normalizePublicKeyOptions: vi.fn((opt) => opt),
}));

const { default: PasskeyAuthenticationController } =
  await import("../../../app/javascript/controllers/passkey_authentication_controller.js");

describe("PasskeyAuthenticationController", () => {
  let controller;

  beforeEach(() => {
    controller = new PasskeyAuthenticationController();
    controller.optionsUrlValue = "/sign/in/passkeys/options";
    controller.verificationUrlValue = "/sign/in/passkeys/verification";
    controller.identifierParamValue = "email";
    controller.turnstileSiteKeyValue = "sitekey123";

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

  test("ensureTurnstileToken: turnstileSiteKeyValue がなければエラー", async () => {
    controller.turnstileSiteKeyValue = "";

    await expect(controller.ensureTurnstileToken()).rejects.toThrow();
  });

  test("csrfToken: meta タグからトークンを取得する", () => {
    const result = controller.csrfToken;
    expect(result).toBe("csrf-token-value");
  });

  test("identifierValue: target があればその値を返す", () => {
    controller.identifierTarget.value = "test@example.com";
    expect(controller.identifierValue).toBe("test@example.com");
  });

  test("identifierValue: target がなければ空文字列を返す", () => {
    controller.hasIdentifierTarget = false;
    expect(controller.identifierValue).toBe("");
  });
});
