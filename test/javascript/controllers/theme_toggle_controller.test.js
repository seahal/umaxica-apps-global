import { beforeEach, describe, expect, test, vi } from "vite-plus/test";

vi.mock("@hotwired/stimulus", () => ({
  Controller: class {
    constructor() {
      this.element = {};
    }

    connect() {}

    dispatch() {}
  },
}));

const { default: ThemeToggleController } =
  await import("../../../app/javascript/controllers/theme_toggle_controller.js");

describe("ThemeToggleController", () => {
  let controller;
  let dispatchEventSpy;

  beforeEach(() => {
    dispatchEventSpy = vi.fn();
    controller = new ThemeToggleController();
    controller.endpointValue = "/preferences/theme";
    controller.currentValue = "sy";

    vi.stubGlobal("document", {
      querySelector: vi.fn((selector) => {
        if (selector.includes("csrf-token")) {
          return { content: "csrf-token-value" };
        }
        return null;
      }),
    });
    vi.stubGlobal("window", {
      dispatchEvent: dispatchEventSpy,
      location: { protocol: "https:" },
    });
    vi.stubGlobal("fetch", vi.fn());
  });

  test("connect: デフォルトテーマを設定する", () => {
    controller.connect();
    expect(controller.currentTheme).toBe("sy");
  });

  test("connect: currentValue がある場合はその値を設定する", () => {
    controller.currentValue = "dr";
    controller.connect();
    expect(controller.currentTheme).toBe("dr");
  });

  test("toggle: 同じテーマの場合は何もしない", () => {
    controller.currentTheme = "dr";
    const event = { currentTarget: { dataset: { theme: "dr" }, value: "dr" } };
    controller.toggle(event);
    expect(controller.currentTheme).toBe("dr");
  });

  test("toggle: 異なるテーマの場合は updateTheme を呼ぶ", () => {
    controller.currentTheme = "dr";
    const event = { currentTarget: { dataset: { theme: "li" }, value: "li" } };
    const spy = vi.spyOn(controller, "updateTheme");
    controller.toggle(event);
    expect(spy).toHaveBeenCalledWith("li");
  });

  test("toggle: dataset.theme が優先", () => {
    controller.currentTheme = "dr";
    const event = { currentTarget: { dataset: { theme: "li" }, value: "dr" } };
    const spy = vi.spyOn(controller, "updateTheme");
    controller.toggle(event);
    expect(spy).toHaveBeenCalledWith("li");
  });

  test("toggle: value が空の場合は何もしない", () => {
    controller.currentTheme = "dr";
    const event = { currentTarget: { dataset: {}, value: "" } };
    controller.toggle(event);
    expect(controller.currentTheme).toBe("dr");
  });

  test("updateTheme: 成功時にCookieを設定する", async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ preference: { ct: "dr" } }),
    });

    let cookiesSet = [];
    Object.defineProperty(document, "cookie", {
      set: (val) => cookiesSet.push(val),
      get: () => "",
    });

    await controller.updateTheme("dr");

    expect(cookiesSet.some((c) => c.startsWith("ct="))).toBe(true);
    expect(controller.currentTheme).toBe("dr");
    expect(dispatchEventSpy).toHaveBeenCalled();
  });

  test("updateTheme: サーバーから返されたテーマを使用する", async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ preference: { ct: "li" } }),
    });

    await controller.updateTheme("dr");
    expect(controller.currentTheme).toBe("li");
  });

  test("updateTheme: 失敗時にエラー��理する", async () => {
    fetch.mockResolvedValueOnce({
      ok: false,
      status: 500,
    });

    const dispatchSpy = vi.spyOn(controller, "dispatch");

    await controller.updateTheme("dr");

    expect(dispatchSpy).toHaveBeenCalled();
  });

  test("updateTheme: 例外時にエラー処理する", async () => {
    fetch.mockRejectedValueOnce(new Error("Network error"));

    const dispatchSpy = vi.spyOn(controller, "dispatch");

    await controller.updateTheme("dr");

    expect(dispatchSpy).toHaveBeenCalled();
  });
});
