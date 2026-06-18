import { beforeEach, describe, expect, test, vi } from "vite-plus/test";

vi.mock("@hotwired/stimulus", () => ({
  Controller: class {
    connect() {}
  },
}));

const { default: HistoryBackController } =
  await import("../../../app/javascript/controllers/history_back_controller.js");

describe("HistoryBackController", () => {
  let controller;
  let event;
  let historyMock;

  beforeEach(() => {
    historyMock = { length: 1, back: vi.fn() };
    vi.stubGlobal("window", { history: historyMock });

    event = { preventDefault: vi.fn() };

    controller = new HistoryBackController();
  });

  test("history.length > 1 のとき、preventDefault を呼び history.back を実行する", () => {
    historyMock.length = 2;
    controller.back(event);

    expect(event.preventDefault).toHaveBeenCalled();
    expect(historyMock.back).toHaveBeenCalled();
  });

  test("history.length <= 1 のとき、なにもしない", () => {
    historyMock.length = 1;
    controller.back(event);

    expect(event.preventDefault).not.toHaveBeenCalled();
    expect(historyMock.back).not.toHaveBeenCalled();
  });
});
