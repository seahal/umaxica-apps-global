import { beforeEach, describe, expect, test, vi } from "vite-plus/test";

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
    }

    connect() {}
  },
}));

const { default: TurnstileController } =
  await import("../../../app/javascript/controllers/turnstile_controller.js");

describe("TurnstileController", () => {
  let controller;
  let render;
  let execute;
  let dispatchEvent;

  beforeEach(() => {
    render = vi.fn();
    execute = vi.fn();
    dispatchEvent = vi.fn();
    controller = new TurnstileController();

    vi.stubGlobal("window", {
      turnstile: { render, execute },
      dispatchEvent,
    });
    vi.stubGlobal(
      "CustomEvent",
      class {
        constructor(type, options) {
          this.type = type;
          this.detail = options.detail;
        }
      },
    );
  });

  test("scheduleChallenge renders visible turnstile once", () => {
    controller.modeValue = "render";
    controller.completed = false;

    controller.scheduleChallenge();
    controller.scheduleChallenge();

    expect(render).toHaveBeenCalledOnce();
    expect(render).toHaveBeenCalledWith(
      controller.containerTarget,
      expect.objectContaining({
        sitekey: "site-key",
      }),
    );
    expect(execute).not.toHaveBeenCalled();
  });

  test("scheduleChallenge executes stealth turnstile", () => {
    controller.modeValue = "execute";
    controller.completed = false;

    controller.scheduleChallenge();

    expect(execute).toHaveBeenCalledOnce();
    expect(execute).toHaveBeenCalledWith(
      controller.containerTarget,
      expect.objectContaining({
        sitekey: "site-key",
      }),
    );
    expect(render).not.toHaveBeenCalled();
  });

  test("success callback stores response token and dispatches event", () => {
    const options = controller.challengeOptions();

    options.callback("response-token");

    expect(controller.responseTarget.value).toBe("response-token");
    expect(dispatchEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: "turnstile:success",
        detail: { widgetId: "turnstile-widget" },
      }),
    );
  });
});
