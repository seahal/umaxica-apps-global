import { beforeEach, describe, expect, test, vi } from "vite-plus/test";

vi.mock("@hotwired/stimulus", () => ({
  Controller: class {
    constructor() {
      this.element = { addEventListener: vi.fn(), removeEventListener: vi.fn() };
    }

    connect() {}
  },
}));

const { default: UnsavedChangesController } =
  await import("../../../app/javascript/controllers/unsaved_changes_controller.js");

describe("UnsavedChangesController", () => {
  let controller;
  let documentMock;
  let windowMock;

  beforeEach(() => {
    documentMock = { addEventListener: vi.fn(), removeEventListener: vi.fn() };
    windowMock = { addEventListener: vi.fn(), removeEventListener: vi.fn(), confirm: vi.fn() };
    vi.stubGlobal("document", documentMock);
    vi.stubGlobal("window", windowMock);

    controller = new UnsavedChangesController();
    controller.messageValue = "Unsaved changes!";
  });

  test("connect: イベントリスナーを登録する", () => {
    controller.connect();
    expect(controller.element.addEventListener).toHaveBeenCalledWith(
      "input",
      controller.handleInput,
    );
    expect(documentMock.addEventListener).toHaveBeenCalledWith(
      "turbo:before-visit",
      controller.handleBeforeVisit,
    );
    expect(windowMock.addEventListener).toHaveBeenCalledWith(
      "beforeunload",
      controller.handleBeforeUnload,
    );
  });

  test("handleInput: dirty フラグを true にする", () => {
    controller.connect();
    controller.handleInput();
    expect(controller.dirty).toBe(true);
  });

  test("handleSubmit: dirty フラグを false にする", () => {
    controller.connect();
    controller.handleInput();
    controller.handleSubmit();
    expect(controller.dirty).toBe(false);
  });

  test("handleBeforeVisit: dirty のとき、ユーザーに確認する", () => {
    controller.connect();
    controller.dirty = true;
    const event = { preventDefault: vi.fn() };

    windowMock.confirm.mockReturnValue(false); // キャンセル
    controller.handleBeforeVisit(event);
    expect(windowMock.confirm).toHaveBeenCalledWith("Unsaved changes!");
    expect(event.preventDefault).toHaveBeenCalled();

    event.preventDefault.mockClear();
    windowMock.confirm.mockReturnValue(true); // OK
    controller.handleBeforeVisit(event);
    expect(event.preventDefault).not.toHaveBeenCalled();
  });

  test("handleBeforeVisit: dirty でないとき、なにもしない", () => {
    controller.connect();
    controller.dirty = false;
    const event = { preventDefault: vi.fn() };

    controller.handleBeforeVisit(event);
    expect(windowMock.confirm).not.toHaveBeenCalled();
    expect(event.preventDefault).not.toHaveBeenCalled();
  });

  test("handleBeforeUnload: dirty のとき、event.preventDefault を呼ぶ", () => {
    controller.connect();
    controller.dirty = true;
    const event = { preventDefault: vi.fn(), returnValue: "" };

    controller.handleBeforeUnload(event);
    expect(event.preventDefault).toHaveBeenCalled();
    expect(event.returnValue).toBe("Unsaved changes!");
  });

  test("handleBeforeUnload: dirty でないとき、なにもしない", () => {
    controller.connect();
    controller.dirty = false;
    const event = { preventDefault: vi.fn(), returnValue: "" };

    controller.handleBeforeUnload(event);
    expect(event.preventDefault).not.toHaveBeenCalled();
    expect(event.returnValue).toBe("");
  });

  test("disconnect: イベントリスナーを解除する", () => {
    controller.connect();
    controller.disconnect();
    expect(controller.element.removeEventListener).toHaveBeenCalledWith(
      "input",
      controller.handleInput,
    );
    expect(documentMock.removeEventListener).toHaveBeenCalledWith(
      "turbo:before-visit",
      controller.handleBeforeVisit,
    );
    expect(windowMock.removeEventListener).toHaveBeenCalledWith(
      "beforeunload",
      controller.handleBeforeUnload,
    );
  });
});
