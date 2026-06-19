import { afterEach, beforeEach, describe, expect, test, vi } from "vite-plus/test";

vi.mock("@hotwired/stimulus", () => ({
  Controller: class {
    constructor() {
      this.containerTarget = {
        dataset: { sitekey: "site-key" },
        id: "turnstile-widget",
      };
      this.responseTarget = { value: "" };
      this.hasContainerTarget = true;
      this.hasResponseTarget = true;
      this.completed = false;
    }

    connect() {}

    disconnect() {}
  },
}));

const { default: TurnstileController } =
  await import("../../src/controllers/turnstile_controller.js");

function restoreReadyState(descriptor) {
  if (descriptor) {
    Object.defineProperty(document, "readyState", descriptor);
  }
}

describe("TurnstileController", () => {
  let controller;
  let render;
  let execute;
  let dispatchEvent;
  let addEventListenerSpy;
  let removeEventListenerSpy;

  beforeEach(() => {
    render = vi.fn();
    execute = vi.fn();
    dispatchEvent = vi.fn();
    addEventListenerSpy = vi.spyOn(document, "addEventListener");
    removeEventListenerSpy = vi.spyOn(document, "removeEventListener");

    vi.stubGlobal("window", {
      turnstile: { render, execute },
      dispatchEvent,
    });
    vi.stubGlobal("CustomEvent", function CustomEventMock(type, options) {
      this.type = type;
      this.detail = options.detail;
    });
  });

  afterEach(() => {
    addEventListenerSpy.mockRestore();
    removeEventListenerSpy.mockRestore();
  });

  function createController() {
    controller = new TurnstileController();
    return controller;
  }

  test("connect binds methods and sets up listeners when api script exists", () => {
    const script = document.createElement("script");
    script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js";
    document.head.appendChild(script);

    const c = createController();
    const originalQuerySelector = document.querySelector;
    document.querySelector = () => script;

    c.connect();

    expect(c.completed).toBe(true);
    expect(addEventListenerSpy).toHaveBeenCalledWith("turbo:load", c.scheduleChallenge, {
      once: true,
    });

    document.querySelector = originalQuerySelector;
    document.head.removeChild(script);
  });

  test("connect adds DOMContentLoaded listener when readyState is loading", () => {
    const c = createController();
    const originalReadyState = Object.getOwnPropertyDescriptor(document, "readyState");
    Object.defineProperty(document, "readyState", {
      value: "loading",
      configurable: true,
    });

    c.connect();

    expect(addEventListenerSpy).toHaveBeenCalledWith("DOMContentLoaded", c.scheduleChallenge, {
      once: true,
    });

    restoreReadyState(originalReadyState);
  });

  test("connect calls scheduleChallenge directly when document is already loaded", () => {
    const c = createController();
    const originalReadyState = Object.getOwnPropertyDescriptor(document, "readyState");
    Object.defineProperty(document, "readyState", {
      value: "complete",
      configurable: true,
    });

    const originalSchedule = c.scheduleChallenge;
    let called = 0;
    c.scheduleChallenge = (...args) => {
      called += 1;
      return originalSchedule.apply(c, args);
    };

    c.connect();

    expect(called).toBe(1);
    c.scheduleChallenge = originalSchedule;
    restoreReadyState(originalReadyState);
  });

  test("disconnect removes all listeners", () => {
    const script = document.createElement("script");
    script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js";
    const scriptRemoveEventListenerSpy = vi.spyOn(script, "removeEventListener");
    document.head.appendChild(script);

    const c = createController();
    c.apiScript = script;

    c.disconnect();

    expect(scriptRemoveEventListenerSpy).toHaveBeenCalledWith("load", c.scheduleChallenge);
    expect(scriptRemoveEventListenerSpy).toHaveBeenCalledWith("error", c.reportScriptError);
    expect(removeEventListenerSpy).toHaveBeenCalledWith("turbo:load", c.scheduleChallenge);
    expect(removeEventListenerSpy).toHaveBeenCalledWith("DOMContentLoaded", c.scheduleChallenge);

    document.head.removeChild(script);
  });

  test("disconnect skips script listener removal when apiScript is absent", () => {
    const c = createController();
    c.apiScript = null;

    c.disconnect();

    expect(removeEventListenerSpy).toHaveBeenCalledWith("turbo:load", c.scheduleChallenge);
    expect(removeEventListenerSpy).toHaveBeenCalledWith("DOMContentLoaded", c.scheduleChallenge);
  });

  test("scheduleChallenge renders visible turnstile once", () => {
    const c = createController();
    c.modeValue = "render";
    c.completed = false;

    c.scheduleChallenge();
    c.scheduleChallenge();

    expect(render).toHaveBeenCalledOnce();
    expect(render).toHaveBeenCalledWith(
      c.containerTarget,
      expect.objectContaining({
        sitekey: "site-key",
      }),
    );
    expect(execute).not.toHaveBeenCalled();
  });

  test("scheduleChallenge executes stealth turnstile", () => {
    const c = createController();
    c.modeValue = "execute";
    c.completed = false;
    render.mockReturnValue("widget-id");

    c.scheduleChallenge();

    expect(render).toHaveBeenCalledOnce();
    expect(render).toHaveBeenCalledWith(
      c.containerTarget,
      expect.objectContaining({
        sitekey: "site-key",
      }),
    );
    expect(execute).toHaveBeenCalledOnce();
    expect(execute).toHaveBeenCalledWith("widget-id");
  });

  test("scheduleChallenge does nothing when already completed", () => {
    const c = createController();
    c.modeValue = "render";
    c.completed = true;

    c.scheduleChallenge();

    expect(render).not.toHaveBeenCalled();
  });

  test("scheduleChallenge does nothing when window.turnstile is missing", () => {
    vi.stubGlobal("window", {
      turnstile: undefined,
      dispatchEvent,
    });
    const c = createController();
    c.modeValue = "render";
    c.completed = false;

    c.scheduleChallenge();

    expect(render).not.toHaveBeenCalled();
  });

  test("scheduleChallenge does nothing when container target is missing", () => {
    const c = createController();
    c.hasContainerTarget = false;
    c.modeValue = "render";
    c.completed = false;

    c.scheduleChallenge();

    expect(render).not.toHaveBeenCalled();
  });

  test("scheduleChallenge does nothing when response target is missing", () => {
    const c = createController();
    c.hasResponseTarget = false;
    c.modeValue = "render";
    c.completed = false;

    c.scheduleChallenge();

    expect(render).not.toHaveBeenCalled();
  });

  test("success callback stores response token and dispatches event", () => {
    const c = createController();
    const options = c.challengeOptions();

    options.callback("response-token");

    expect(c.responseTarget.value).toBe("response-token");
    expect(dispatchEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: "turnstile:success",
        detail: { widgetId: "turnstile-widget" },
      }),
    );
  });

  test("error callback clears response and dispatches event", () => {
    const c = createController();
    c.responseTarget.value = "old";
    const options = c.challengeOptions();

    const result = options["error-callback"]("E-123");

    expect(c.responseTarget.value).toBe("");
    expect(result).toBe(true);
    expect(dispatchEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: "turnstile:error",
        detail: { errorCode: "E-123", widgetId: "turnstile-widget" },
      }),
    );
  });

  test("expired callback clears response and dispatches event", () => {
    const c = createController();
    c.responseTarget.value = "old";
    const options = c.challengeOptions();

    options["expired-callback"]();

    expect(c.responseTarget.value).toBe("");
    expect(dispatchEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: "turnstile:expired",
        detail: { widgetId: "turnstile-widget" },
      }),
    );
  });

  test("timeout callback clears response and dispatches event", () => {
    const c = createController();
    c.responseTarget.value = "old";
    const options = c.challengeOptions();

    options["timeout-callback"]();

    expect(c.responseTarget.value).toBe("");
    expect(dispatchEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: "turnstile:timeout",
        detail: { widgetId: "turnstile-widget" },
      }),
    );
  });

  test("unsupported callback clears response and dispatches event", () => {
    const c = createController();
    c.responseTarget.value = "old";
    const options = c.challengeOptions();

    options["unsupported-callback"]();

    expect(c.responseTarget.value).toBe("");
    expect(dispatchEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: "turnstile:unsupported",
        detail: { widgetId: "turnstile-widget" },
      }),
    );
  });

  test("dispatchTurnstileEvent creates and dispatches CustomEvent", () => {
    const c = createController();
    c.dispatchTurnstileEvent("test", { foo: "bar" });

    expect(dispatchEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: "turnstile:test",
        detail: { foo: "bar", widgetId: "turnstile-widget" },
      }),
    );
  });

  test("reportScriptError logs error to console", () => {
    const c = createController();
    const consoleSpy = vi.spyOn(console, "error").mockImplementation(() => {});

    c.reportScriptError();

    expect(consoleSpy).toHaveBeenCalledWith("Turnstile script failed to load");
    consoleSpy.mockRestore();
  });
});
