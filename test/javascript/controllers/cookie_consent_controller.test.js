import { beforeEach, describe, expect, test, vi } from "vite-plus/test";

vi.mock("@hotwired/stimulus", () => ({
  Controller: class {
    constructor() {
      this.bannerTarget = { classList: { add: vi.fn(), remove: vi.fn() } };
      this.hasBannerTarget = true;
      this.element = {};
    }

    connect() {}

    dispatch() {}
  },
}));

const { default: CookieConsentController } =
  await import("../../../app/javascript/controllers/cookie_consent_controller.js");

describe("CookieConsentController", () => {
  let controller;

  beforeEach(() => {
    controller = new CookieConsentController();
    controller.endpointValue = "/preferences/cookie";
    controller.consentedValue = false;

    vi.stubGlobal("document", {
      querySelector: vi.fn((selector) => {
        if (selector.includes("csrf-token")) {
          return { content: "csrf-token-value" };
        }
        return null;
      }),
    });
    vi.stubGlobal("fetch", vi.fn());
    vi.stubGlobal("window", {
      dispatchEvent: vi.fn(),
    });
  });

  test("connect: 未同意時にバナーを表示する", () => {
    controller.consentedValue = false;
    controller.connect();
    expect(controller.bannerTarget.classList.remove).toHaveBeenCalledWith("hidden");
  });

  test("connect: 同意済みにはバナーを表示しない", () => {
    controller.consentedValue = true;
    controller.connect();
    expect(controller.bannerTarget.classList.remove).not.toHaveBeenCalledWith("hidden");
  });

  test("showBanner: バナーを表示する", () => {
    controller.showBanner();
    expect(controller.bannerTarget.classList.remove).toHaveBeenCalledWith("hidden");
  });

  test("hideBanner: バナーを非表示にする", () => {
    controller.hideBanner();
    expect(controller.bannerTarget.classList.add).toHaveBeenCalledWith("hidden");
  });

  test("accept: 同意を送信する", async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ preference: { consented: true } }),
    });

    const event = { preventDefault: vi.fn() };
    await controller.accept(event);

    expect(fetch).toHaveBeenCalledWith(
      "/preferences/cookie",
      expect.objectContaining({
        method: "PATCH",
      }),
    );
  });

  test("reject: 拒絶を送信する", async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ preference: { consented: false } }),
    });

    const event = { preventDefault: vi.fn() };
    await controller.reject(event);

    expect(fetch).toHaveBeenCalledWith(
      "/preferences/cookie",
      expect.objectContaining({
        method: "PATCH",
      }),
    );
  });

  test("submitConsent: 成功時にCookieを設定しバナーを閉じる", async () => {
    vi.stubGlobal("document", {
      querySelector: vi.fn((selector) => {
        if (selector.includes("csrf-token")) {
          return { content: "csrf-token-value" };
        }
        return null;
      }),
    });

    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ preference: { consented: true } }),
    });

    let cookiesSet = [];
    Object.defineProperty(document, "cookie", {
      set: (val) => cookiesSet.push(val),
      get: () => "",
    });

    await controller.submitConsent(true);

    expect(cookiesSet.some((c) => c.startsWith("preference_consented="))).toBe(true);
    expect(controller.bannerTarget.classList.add).toHaveBeenCalledWith("hidden");
  });

  test("submitConsent: 失敗時にエラー処理する", async () => {
    fetch.mockResolvedValueOnce({
      ok: false,
      status: 500,
    });

    const dispatchSpy = vi.spyOn(controller, "dispatch");

    await controller.submitConsent(true);

    expect(dispatchSpy).toHaveBeenCalled();
  });

  test("submitConsent: 例外時にエラー処理する", async () => {
    fetch.mockRejectedValueOnce(new Error("Network error"));

    const dispatchSpy = vi.spyOn(controller, "dispatch");

    await controller.submitConsent(true);

    expect(dispatchSpy).toHaveBeenCalled();
  });
});
