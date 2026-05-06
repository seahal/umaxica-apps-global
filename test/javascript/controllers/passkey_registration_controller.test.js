import { beforeEach, describe, expect, test, vi } from "vite-plus/test";

vi.mock("@hotwired/stimulus", () => ({
  Controller: class {
    constructor() {
      this.descriptionTarget = { value: "" };
      this.errorTarget = { textContent: "", classList: { add: vi.fn(), remove: vi.fn() } };
      this.statusTarget = { textContent: "", classList: { add: vi.fn(), remove: vi.fn() } };
      this.hasDescriptionTarget = true;
      this.hasErrorTarget = true;
      this.hasStatusTarget = true;
    }

    connect() {}

    dispatch() {}
  },
}));

vi.mock("controllers/webauthn_utils", () => ({
  normalizePublicKeyOptions: vi.fn((opt) => opt),
}));

const { default: PasskeyRegistrationController } =
  await import("../../../app/javascript/controllers/passkey_registration_controller.js");

describe("PasskeyRegistrationController", () => {
  let controller;

  beforeEach(() => {
    controller = new PasskeyRegistrationController();
    controller.optionsUrlValue = "/configuration/passkeys/options";
    controller.verificationUrlValue = "/configuration/passkeys/verification";
    controller.beginUrlValue = "/configuration/passkeys/begin";
    controller.finishUrlValue = "/configuration/passkeys/finish";
    controller.successRedirectUrlValue = "/settings";

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
});
