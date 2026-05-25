import { afterEach, beforeEach, describe, expect, test, vi } from "vite-plus/test";

vi.mock("@hotwired/stimulus", () => ({
  Controller: class {
    constructor() {
      this.statusTarget = { textContent: "" };
      this.buttonTarget = { disabled: false, textContent: "" };
      this.inputTarget = { value: "", focus: vi.fn() };
      this.hasInputTarget = true;
    }

    connect() {}
  },
}));

const { default: OtpResendController } =
  await import("../../../app/javascript/controllers/otp_resend_controller.js");

describe("OtpResendController", () => {
  let controller;

  beforeEach(() => {
    vi.useFakeTimers();
    controller = new OtpResendController();
    controller.endpointValue = "/otp/resend";
    controller.stateValue = "some-state";
    controller.buttonLabelValue = "Resend OTP";
    controller.sentMessageValue = "OTP Sent!";
    controller.tooSoonMessageValue = "Too soon";
    controller.failedMessageValue = "Failed to send";

    vi.stubGlobal("fetch", vi.fn());
    vi.stubGlobal("document", {
      querySelector: vi.fn((selector) => {
        if (selector === "meta[name='csrf-token']") {
          return { getAttribute: () => "csrf-token-value" };
        }
        return null;
      }),
    });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  test("connect: タイマーを初期化する", () => {
    controller.connect();
    expect(controller.remainingSeconds).toBe(0);
    expect(controller.countdownTimer).toBeNull();
  });

  test("disconnect: カウントダウンを停止する", () => {
    controller.remainingSeconds = 5;
    controller.countdownTimer = setInterval(() => {}, 1000);
    const spy = vi.spyOn(controller, "stopCountdown");
    controller.disconnect();
    expect(spy).toHaveBeenCalled();
  });

  test("resend: 成功時にステータスを更新し、入力をクリアする", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ status: 200, json: () => Promise.resolve({ resendable: true }) }),
    );

    const event = { preventDefault: vi.fn() };
    await controller.resend(event);

    expect(controller.statusTarget.textContent).toBe("OTP Sent!");
    expect(controller.inputTarget.value).toBe("");
    expect(controller.inputTarget.focus).toHaveBeenCalled();
  });

  test("resend: 429 (Too Many Requests) のときにカウントダウンを開始する", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ status: 429, json: () => Promise.resolve({ retry_after: 10 }) }),
    );

    const event = { preventDefault: vi.fn() };
    await controller.resend(event);

    expect(controller.statusTarget.textContent).toBe("Too soon");
    expect(controller.buttonTarget.disabled).toBe(true);
    expect(controller.buttonTarget.textContent).toContain("(10s)");

    vi.advanceTimersByTime(1000);
    expect(controller.buttonTarget.textContent).toContain("(9s)");

    vi.advanceTimersByTime(9000);
    expect(controller.buttonTarget.disabled).toBe(false);
    expect(controller.buttonTarget.textContent).toBe("Resend OTP");
  });

  test("resend: 失敗時にエラーメッセージを表示する", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ status: 500, json: () => Promise.resolve({}) }),
    );

    const event = { preventDefault: vi.fn() };
    await controller.resend(event);

    expect(controller.statusTarget.textContent).toBe("Failed to send");
  });

  test("resend: カウントダウン中は何もしない", async () => {
    controller.remainingSeconds = 5;
    const event = { preventDefault: vi.fn() };
    await controller.resend(event);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(controller.statusTarget.textContent).toBe("");
  });

  test("resend: 200 だが resendable でないとき失敗メッセージを表示する", async () => {
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValue({ status: 200, json: () => Promise.resolve({ resendable: false }) }),
    );

    const event = { preventDefault: vi.fn() };
    await controller.resend(event);

    expect(controller.statusTarget.textContent).toBe("Failed to send");
  });

  test("resend: fetch 例外時にエラーメッセージを表示する", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("Network error")));

    const event = { preventDefault: vi.fn() };
    await controller.resend(event);

    expect(controller.statusTarget.textContent).toBe("Failed to send");
  });

  test("startCountdown: 0 秒以下のときすぐにリセットする", () => {
    controller.startCountdown(0);
    expect(controller.remainingSeconds).toBe(0);
    expect(controller.buttonTarget.disabled).toBe(false);
    expect(controller.buttonTarget.textContent).toBe("Resend OTP");
  });

  test("renderButton: カウントダウン終了時にボタンラベルを表示する", () => {
    controller.remainingSeconds = 0;
    controller.renderButton();
    expect(controller.buttonTarget.disabled).toBe(false);
    expect(controller.buttonTarget.textContent).toBe("Resend OTP");
  });
});
