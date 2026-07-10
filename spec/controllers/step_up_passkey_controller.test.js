import { beforeEach, describe, expect, test, vi } from "vitest";

vi.mock("@hotwired/stimulus", () => ({
  Controller: class {
    constructor() {
      this.challengeIdTarget = { value: "" };
      this.credentialJsonTarget = { value: "" };
      this.errorTarget = { textContent: "", classList: { add: vi.fn(), remove: vi.fn() } };
      this.statusTarget = { textContent: "", classList: { add: vi.fn(), remove: vi.fn() } };
      this.hasErrorTarget = true;
      this.hasStatusTarget = true;
      this.element = { closest: vi.fn(() => ({ requestSubmit: vi.fn() })) };
    }

    connect() {}
  },
}));

vi.mock("../../src/controllers/webauthn_utils.js", () => ({
  normalizePublicKeyOptions: vi.fn((opt) => opt),
}));

const { default: StepUpPasskeyController } =
  await import("../../src/controllers/step_up_passkey_controller.js");

describe("StepUpPasskeyController", () => {
  let controller;

  beforeEach(() => {
    controller = new StepUpPasskeyController();
    controller.optionsValue = JSON.stringify({ challenge: "abc" });
    controller.challengeIdValue = "challenge-123";

    vi.stubGlobal("window", { PublicKeyCredential: true });
    vi.stubGlobal("navigator", { credentials: { get: vi.fn() } });
    vi.stubGlobal("btoa", (str) => Buffer.from(str, "binary").toString("base64"));
  });

  test("authenticate: 成功時にフォームを送信する", async () => {
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

    expect(controller.credentialJsonTarget.value).toContain('"id":"cred-id"');
    expect(controller.challengeIdTarget.value).toBe("challenge-123");
    expect(controller.element.closest).toHaveBeenCalledWith("form");
  });

  test("authenticate: NotAllowedError のときに適切なエラーメッセージを表示する", async () => {
    const error = new Error("Cancelled");
    error.name = "NotAllowedError";
    navigator.credentials.get.mockRejectedValue(error);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("認証がキャンセルされました");
  });

  test("authenticate: WebAuthn 未対応時にエラーを表示する", async () => {
    window.PublicKeyCredential = false;

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("このブラウザはPasskeyに対応していません");
  });

  test("authenticate: optionsValue が空のときエラーを表示する", async () => {
    controller.optionsValue = "";

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("認証オプションの取得に失敗しました");
  });

  test("authenticate: challengeIdValue が空のときエラーを表示する", async () => {
    controller.challengeIdValue = "";

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("認証オプションの取得に失敗しました");
  });

  test("authenticate: SecurityError のときに適切なエラーメッセージを表示する", async () => {
    const error = new Error("Security issue");
    error.name = "SecurityError";
    navigator.credentials.get.mockRejectedValue(error);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("セキュリティエラーが発生しました");
  });

  test("authenticate: その他のエラーのときにメッセージを表示する", async () => {
    const error = new Error("Something went wrong");
    navigator.credentials.get.mockRejectedValue(error);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("Something went wrong");
  });

  test("encodeCredential: userHandle がある場合も正しくエンコードする", async () => {
    const mockCredential = {
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
      getClientExtensionResults: () => ({ credProps: { rk: true } }),
    };
    navigator.credentials.get.mockResolvedValue(mockCredential);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.credentialJsonTarget.value).toContain("platform");
    expect(controller.credentialJsonTarget.value).toContain("userHandle");
  });

  test("encodeCredential: authenticatorAttachment が undefined の場合 null になる", async () => {
    const mockCredential = {
      id: "cred-id",
      rawId: new Uint8Array([1]).buffer,
      type: "public-key",
      authenticatorAttachment: undefined,
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

    const parsed = JSON.parse(controller.credentialJsonTarget.value);
    expect(parsed.authenticatorAttachment).toBeNull();
    expect(parsed.response.userHandle).toBeNull();
  });

  test("showError: errorTarget がないときは何もしない", () => {
    controller.hasErrorTarget = false;
    controller.showError("test error");
    expect(controller.errorTarget.textContent).toBe("");
  });

  test("showError: statusTarget がないときは何もしない", () => {
    controller.hasStatusTarget = false;
    controller.showError("test error");
    expect(controller.errorTarget.textContent).toBe("test error");
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
    expect(controller.statusTarget.classList.add).toHaveBeenCalledWith("hidden");
  });

  test("clearMessages: statusTarget がないとき", () => {
    controller.hasStatusTarget = false;
    controller.clearMessages();
    expect(controller.errorTarget.textContent).toBe("");
    expect(controller.errorTarget.classList.add).toHaveBeenCalledWith("hidden");
  });

  test("authenticate: error.message が空のときデフォルトメッセージを表示する", async () => {
    const error = new Error();
    error.name = "GenericError";
    navigator.credentials.get.mockRejectedValue(error);

    const event = { preventDefault: vi.fn() };
    await controller.authenticate(event);

    expect(controller.errorTarget.textContent).toBe("認証中にエラーが発生しました");
  });
});
