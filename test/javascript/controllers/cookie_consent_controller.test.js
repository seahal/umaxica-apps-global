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

  test("connect shows the banner when consent is missing", () => {
    controller.consentedValue = false;
    controller.connect();
    expect(controller.bannerTarget.classList.remove).toHaveBeenCalledWith("hidden");
  });

  test("connect does not show the banner when already consented", () => {
    controller.consentedValue = true;
    controller.connect();
    expect(controller.bannerTarget.classList.remove).not.toHaveBeenCalledWith("hidden");
  });

  test("connect does nothing without a banner target", () => {
    controller.consentedValue = false;
    controller.hasBannerTarget = false;
    controller.connect();
    expect(controller.bannerTarget.classList.remove).not.toHaveBeenCalledWith("hidden");
  });

  test("showBanner shows the banner", () => {
    controller.showBanner();
    expect(controller.bannerTarget.classList.remove).toHaveBeenCalledWith("hidden");
  });

  test("hideBanner hides the banner", () => {
    controller.hideBanner();
    expect(controller.bannerTarget.classList.add).toHaveBeenCalledWith("hidden");
  });

  test("accept submits consent", async () => {
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

  test("reject submits refusal", async () => {
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

  test("submitConsent hides the banner without writing a JS consent cookie", async () => {
    vi.stubGlobal("document", {
      querySelector: vi.fn(() => ({ content: "csrf-token-value" })),
    });

    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ preference: { consented: true } }),
    });

    await controller.submitConsent(true);

    expect(controller.bannerTarget.classList.add).toHaveBeenCalledWith("hidden");
  });

  test("submitConsent dispatches accepted fallback when preference is missing", async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({}),
    });

    await controller.submitConsent(true);

    expect(controller.bannerTarget.classList.add).toHaveBeenCalledWith("hidden");
  });

  test("submitConsent dispatches refusal fallback when preference consent is missing", async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ preference: {} }),
    });

    await controller.submitConsent(false);

    expect(controller.bannerTarget.classList.add).toHaveBeenCalledWith("hidden");
  });

  test("submitConsent dispatches an error when the response fails", async () => {
    fetch.mockResolvedValueOnce({
      ok: false,
      status: 500,
    });

    const dispatchSpy = vi.spyOn(controller, "dispatch");

    await controller.submitConsent(true);

    expect(dispatchSpy).toHaveBeenCalled();
  });

  test("submitConsent dispatches an error on exceptions", async () => {
    fetch.mockRejectedValueOnce(new Error("Network error"));

    const dispatchSpy = vi.spyOn(controller, "dispatch");

    await controller.submitConsent(true);

    expect(dispatchSpy).toHaveBeenCalled();
  });
});
