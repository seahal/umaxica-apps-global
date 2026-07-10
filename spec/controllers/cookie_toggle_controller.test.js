import { beforeEach, describe, expect, test, vi } from "vitest";

vi.mock("@hotwired/stimulus", () => ({
  Controller: class {
    constructor() {
      this.checkboxTargets = [];
      this.statusTarget = { textContent: "" };
      this.hasStatusTarget = false;
      this.element = { querySelector: vi.fn() };
    }

    connect() {}
  },
}));

const { default: CookieToggleController } =
  await import("../../src/controllers/cookie_toggle_controller.js");

describe("CookieToggleController", () => {
  let controller;

  beforeEach(() => {
    controller = new CookieToggleController();
    vi.stubGlobal("window", {
      location: {
        origin: "http://localhost:3000",
        search: "?ct=dr&lx=en&ri=us&tz=asia/tokyo",
      },
    });
    vi.stubGlobal("fetch", vi.fn());
  });

  test("connect: updateStatus と setupFormListener を呼ぶ", () => {
    const updateSpy = vi.spyOn(controller, "updateStatus");
    const setupSpy = vi.spyOn(controller, "setupFormListener");
    controller.connect();
    expect(updateSpy).toHaveBeenCalled();
    expect(setupSpy).toHaveBeenCalled();
  });

  test("updateStatus: チェックボックスの数に応じてステータスを更新する", () => {
    const cb1 = { checked: true };
    const cb2 = { checked: false };
    controller.checkboxTargets = [cb1, cb2];
    controller.statusTarget = { textContent: "" };
    controller.hasStatusTarget = true;

    controller.updateStatus();
    expect(controller.statusTarget.textContent).toBe("1 / 2 cookies enabled");
  });

  test("updateStatus: statusTarget がないときは何もしない", () => {
    controller.hasStatusTarget = false;
    controller.updateStatus();
    expect(controller.statusTarget.textContent).toBe("");
  });

  test("toggle: ステータスを更新する", () => {
    const spy = vi.spyOn(controller, "updateStatus");
    controller.toggle({});
    expect(spy).toHaveBeenCalled();
  });

  test("syncCheckboxesFromAPI syncs checkboxes from the API result", () => {
    const functionalCb = { checked: false };
    controller.element.querySelector.mockReturnValue(functionalCb);

    controller.syncCheckboxesFromAPI({ functional: true });
    expect(functionalCb.checked).toBe(true);
  });

  test("syncCheckboxesFromAPI: チェックボックスがない場合はスキップする", () => {
    controller.element.querySelector.mockReturnValue(null);

    expect(() => controller.syncCheckboxesFromAPI({ functional: true })).not.toThrow();
  });

  test("syncCheckboxesFromAPI skips entries missing from the API result", () => {
    const functionalCb = { checked: true };
    controller.element.querySelector.mockReturnValue(functionalCb);

    controller.syncCheckboxesFromAPI({});
    expect(functionalCb.checked).toBe(true);
  });

  test("setupFormListener: form があるときリスナーを登録する", () => {
    const form = { addEventListener: vi.fn() };
    controller.element.querySelector.mockReturnValue(form);
    controller.setupFormListener();
    expect(form.addEventListener).toHaveBeenCalledWith("turbo:submit-end", expect.any(Function));
  });

  test("setupFormListener: turbo:submit-end で onFormSubmitEnd を呼ぶ", async () => {
    const form = { addEventListener: vi.fn() };
    controller.element.querySelector.mockReturnValue(form);
    controller.setupFormListener();

    const [, handler] = form.addEventListener.mock.calls.find(
      ([event]) => event === "turbo:submit-end",
    );

    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({}) }),
    );
    const spy = vi.spyOn(controller, "onFormSubmitEnd");

    await handler({ detail: { success: true } });
    expect(spy).toHaveBeenCalled();
  });

  test("setupFormListener: form のリスナー内で onFormSubmitEnd を呼ぶ", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ functional: true }) }),
    );
    const syncSpy = vi.spyOn(controller, "syncCheckboxesFromAPI");

    const event = { detail: { success: true } };
    await controller.onFormSubmitEnd(event);
    expect(syncSpy).toHaveBeenCalled();
  });

  test("setupFormListener: form がないとき何もしない", () => {
    controller.element.querySelector.mockReturnValue(null);
    controller.setupFormListener();
    expect(controller.element.querySelector).toHaveBeenCalledWith("form");
  });

  test("onFormSubmitEnd: 成功時に API から同期する", async () => {
    const consent = { functional: true };
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve(consent) }),
    );

    const syncSpy = vi.spyOn(controller, "syncCheckboxesFromAPI");
    const updateSpy = vi.spyOn(controller, "updateStatus");

    const event = { detail: { success: true } };
    await controller.onFormSubmitEnd(event);

    expect(syncSpy).toHaveBeenCalledWith(consent);
    expect(updateSpy).toHaveBeenCalled();
  });

  test("onFormSubmitEnd: 失敗時は何もしない", async () => {
    const updateSpy = vi.spyOn(controller, "updateStatus");
    const event = { detail: { success: false } };
    await controller.onFormSubmitEnd(event);
    expect(updateSpy).not.toHaveBeenCalled();
  });

  test("onFormSubmitEnd: fetch 失敗時に updateStatus を呼ぶ", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("Network error")));
    const updateSpy = vi.spyOn(controller, "updateStatus");

    const event = { detail: { success: true } };
    await controller.onFormSubmitEnd(event);
    expect(updateSpy).toHaveBeenCalled();
  });

  test("onFormSubmitEnd: consentState が falsy のとき何もしない", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve(null) }),
    );
    const syncSpy = vi.spyOn(controller, "syncCheckboxesFromAPI");
    const updateSpy = vi.spyOn(controller, "updateStatus");

    const event = { detail: { success: true } };
    await controller.onFormSubmitEnd(event);

    expect(syncSpy).not.toHaveBeenCalled();
    expect(updateSpy).not.toHaveBeenCalled();
  });

  test("fetchCookieConsent: レスポンスが OK でないときエラーを投げる", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 500 }));
    await expect(controller.fetchCookieConsent()).rejects.toThrow("HTTP error! status: 500");
  });

  test("fetchCookieConsent: 現在の context query を引き継ぐ", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ consented: false }) }),
    );

    await controller.fetchCookieConsent();

    expect(fetch).toHaveBeenCalledWith(
      "http://localhost:3000/web/v0/cookie?ct=dr&lx=en&ri=us&tz=asia/tokyo",
    );
  });
});
