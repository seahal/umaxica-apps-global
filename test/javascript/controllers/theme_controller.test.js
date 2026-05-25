import { beforeEach, describe, expect, test, vi } from "vite-plus/test";

vi.mock("@hotwired/stimulus", () => ({
  // eslint-disable-next-line @typescript-eslint/no-extraneous-class
  Controller: class {
    connect() {}
  },
}));

const { default: ThemeController } =
  await import("../../../app/javascript/controllers/theme_controller.js");

// ──────────────────────────────────────────────
// DOM グローバルのモック
// ──────────────────────────────────────────────

let cookieReadValue = "";
let cookieWritten = [];

const classListMock = {
  store: new Set(),
  add(...cls) {
    cls.forEach((c) => this.store.add(c));
  },
  remove(...cls) {
    cls.forEach((c) => this.store.delete(c));
  },
  toggle(cls, force) {
    if (force) {
      this.store.add(cls);
    } else {
      this.store.delete(cls);
    }
  },
  has(cls) {
    return this.store.has(cls);
  },
};

const documentMock = {
  get cookie() {
    return cookieReadValue;
  },
  set cookie(val) {
    cookieWritten.push(val);
  },
  documentElement: { dataset: {}, classList: classListMock },
  getElementById: vi.fn(() => null),
  querySelector: vi.fn(() => null),
  addEventListener: vi.fn(),
};

const windowMock = { matchMedia: vi.fn(() => ({ matches: false, addEventListener: vi.fn() })) };

function makeController() {
  const controller = new ThemeController();
  controller.element = { querySelector: vi.fn() };
  return controller;
}

beforeEach(() => {
  cookieReadValue = "";
  cookieWritten = [];
  classListMock.store = new Set();
  documentMock.documentElement.dataset = {};
  windowMock.matchMedia.mockReturnValue({ matches: false, addEventListener: vi.fn() });
  documentMock.getElementById.mockReturnValue(null);
  documentMock.querySelector.mockReturnValue(null);
  documentMock.addEventListener.mockReset();

  vi.stubGlobal("document", documentMock);
  vi.stubGlobal("window", windowMock);
  vi.stubGlobal("location", { protocol: "https:" });
});

// ──────────────────────────────────────────────
// connect
// ──────────────────────────────────────────────

describe("connect", () => {
  test("syncRadio を呼ぶ", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("Failed")));
    const controller = makeController();
    const spy = vi.spyOn(controller, "syncRadio");
    controller.connect();
    await vi.waitFor(() => {
      expect(spy).toHaveBeenCalledOnce();
    });
  });
});

// ──────────────────────────────────────────────
// select
// ──────────────────────────────────────────────

describe("select", () => {
  test('"dark" → ct=dr クッキーを設定する', () => {
    const controller = makeController();
    controller.select({ target: { value: "dark" } });
    expect(cookieWritten).toContain("ct=dr; path=/; max-age=31536000; samesite=lax; secure");
  });

  test('"light" → ct=li クッキーを設定する', () => {
    const controller = makeController();
    controller.select({ target: { value: "light" } });
    expect(cookieWritten).toContain("ct=li; path=/; max-age=31536000; samesite=lax; secure");
  });

  test('"system" → ct=sy クッキーを設定する', () => {
    const controller = makeController();
    controller.select({ target: { value: "system" } });
    expect(cookieWritten).toContain("ct=sy; path=/; max-age=31536000; samesite=lax; secure");
  });

  test("未知の値はデフォルトで ct=sy になる", () => {
    const controller = makeController();
    controller.select({ target: { value: "unknown" } });
    expect(cookieWritten).toContain("ct=sy; path=/; max-age=31536000; samesite=lax; secure");
  });

  test("https のとき secure フラグが付く", () => {
    const controller = makeController();
    controller.select({ target: { value: "dark" } });
    expect(cookieWritten[0]).toMatch(/; secure$/);
  });

  test("http のとき secure フラグが付かない", () => {
    vi.stubGlobal("location", { protocol: "http:" });
    const controller = makeController();
    controller.select({ target: { value: "dark" } });
    expect(cookieWritten[0]).not.toMatch(/; secure$/);
  });
});

// ──────────────────────────────────────────────
// syncRadio
// ──────────────────────────────────────────────

describe("syncRadio", () => {
  test('ct=dr のとき radio[value="dark"] をチェックする', () => {
    cookieReadValue = "ct=dr";
    const radio = { checked: false };
    const controller = makeController();
    controller.element.querySelector.mockReturnValue(radio);
    controller.syncRadio();
    expect(controller.element.querySelector).toHaveBeenCalledWith('input[value="dark"]');
    expect(radio.checked).toBe(true);
  });

  test('ct=li のとき radio[value="light"] をチェックする', () => {
    cookieReadValue = "ct=li";
    const radio = { checked: false };
    const controller = makeController();
    controller.element.querySelector.mockReturnValue(radio);
    controller.syncRadio();
    expect(controller.element.querySelector).toHaveBeenCalledWith('input[value="light"]');
    expect(radio.checked).toBe(true);
  });

  test('ct=sy のとき radio[value="system"] をチェックする', () => {
    cookieReadValue = "ct=sy";
    const radio = { checked: false };
    const controller = makeController();
    controller.element.querySelector.mockReturnValue(radio);
    controller.syncRadio();
    expect(controller.element.querySelector).toHaveBeenCalledWith('input[value="system"]');
    expect(radio.checked).toBe(true);
  });

  test("ct クッキーがない場合は system にフォールバックする", () => {
    cookieReadValue = "other=value";
    const radio = { checked: false };
    const controller = makeController();
    controller.element.querySelector.mockReturnValue(radio);
    controller.syncRadio();
    expect(controller.element.querySelector).toHaveBeenCalledWith('input[value="system"]');
    expect(radio.checked).toBe(true);
  });

  test("クッキーが空の場合は system にフォールバックする", () => {
    cookieReadValue = "";
    const radio = { checked: false };
    const controller = makeController();
    controller.element.querySelector.mockReturnValue(radio);
    controller.syncRadio();
    expect(controller.element.querySelector).toHaveBeenCalledWith('input[value="system"]');
  });

  test("対応する radio がない場合はエラーにならない", () => {
    cookieReadValue = "ct=dr";
    const controller = makeController();
    controller.element.querySelector.mockReturnValue(null);
    expect(() => controller.syncRadio()).not.toThrow();
  });

  test("複数クッキーがある場合も ct を正しく読む", () => {
    cookieReadValue = "foo=bar; ct=li; baz=qux";
    const radio = { checked: false };
    const controller = makeController();
    controller.element.querySelector.mockReturnValue(radio);
    controller.syncRadio();
    expect(controller.element.querySelector).toHaveBeenCalledWith('input[value="light"]');
  });
});

// ──────────────────────────────────────────────
// applyThemeFromCookie (統合テスト)
// ──────────────────────────────────────────────

describe("applyThemeFromCookie (統合テスト)", () => {
  test("ct=dr クッキーでダークテーマを適用する", () => {
    cookieReadValue = "ct=dr";
    const controller = makeController();
    controller.select({ target: { value: "dark" } });

    // select した時点でクッキーが書き込まれ、applyThemeFromCookie が呼ばれる
    // classListMock に dark クラスが追加されているか確認
    expect(classListMock.has("dark")).toBe(true);
    expect(classListMock.has("theme-dark")).toBe(true);
  });

  test("ct=li クッキーでライトテーマを適用する", () => {
    cookieReadValue = "ct=li";
    const controller = makeController();
    controller.select({ target: { value: "light" } });

    expect(classListMock.has("dark")).toBe(false);
    expect(classListMock.has("theme-light")).toBe(true);
  });

  test("ct=sy クッキーでシステムテーマを適用する (matches: false)", () => {
    cookieReadValue = "ct=sy";
    windowMock.matchMedia.mockReturnValue({ matches: false, addEventListener: vi.fn() });
    const controller = makeController();
    controller.select({ target: { value: "system" } });

    expect(classListMock.has("dark")).toBe(false);
    expect(classListMock.has("theme-system")).toBe(true);
  });

  test("ct=sy クッキーでシステムテーマを適用する (matches: true)", () => {
    cookieReadValue = "ct=sy";
    windowMock.matchMedia.mockReturnValue({ matches: true, addEventListener: vi.fn() });
    const controller = makeController();
    controller.select({ target: { value: "system" } });

    expect(classListMock.has("dark")).toBe(true);
    expect(classListMock.has("theme-system")).toBe(true);
  });

  test("クッキーがない場合のテーマはシステムデフォルト", () => {
    cookieReadValue = "";
    windowMock.matchMedia.mockReturnValue({ matches: false, addEventListener: vi.fn() });
    const controller = makeController();
    controller.select({ target: { value: "system" } });

    expect(classListMock.has("dark")).toBe(false);
    expect(classListMock.has("theme-system")).toBe(true);
  });

  test("html.dataset.theme に正しい値が設定される", () => {
    cookieReadValue = "ct=dr";
    const controller = makeController();
    controller.select({ target: { value: "dark" } });

    expect(documentMock.documentElement.dataset.theme).toBe("dark");
  });

  test("js-theme-cookie-value 要素がある場合、テーマ値を設定する", () => {
    cookieReadValue = "ct=li";
    const valueEl = { textContent: "" };
    documentMock.querySelector.mockReturnValue(valueEl);
    const controller = makeController();
    controller.select({ target: { value: "light" } });

    expect(documentMock.querySelector).toHaveBeenCalledWith("#js-theme-cookie-value");
    expect(valueEl.textContent).toBe("light");
  });

  test("js-theme-cookie-value 要素がない場合、エラーにならない", () => {
    cookieReadValue = "ct=dr";
    documentMock.querySelector.mockReturnValue(null);
    const controller = makeController();

    expect(() => controller.select({ target: { value: "dark" } })).not.toThrow();
  });

  test("システムテーマが選択されると matchMedia が呼ばれる", () => {
    cookieReadValue = "ct=sy";
    const matchMediaMock = vi.fn(() => ({ matches: false, addEventListener: vi.fn() }));
    windowMock.matchMedia = matchMediaMock;
    const controller = makeController();

    controller.select({ target: { value: "system" } });
    expect(matchMediaMock).toHaveBeenCalledWith("(prefers-color-scheme: dark)");
  });

  test("システムテーマの change イベントで dark クラスが切り替わる", () => {
    let changeCallback = null;
    const matchMediaResult = {
      matches: false,
      addEventListener: vi.fn((event, cb) => {
        if (event === "change") changeCallback = cb;
      }),
    };
    windowMock.matchMedia = vi.fn(() => matchMediaResult);
    cookieReadValue = "ct=sy";
    const controller = makeController();
    controller.select({ target: { value: "system" } });
    expect(changeCallback).not.toBeNull();

    matchMediaResult.matches = true;
    changeCallback();
    expect(classListMock.has("dark")).toBe(true);

    matchMediaResult.matches = false;
    changeCallback();
    expect(classListMock.has("dark")).toBe(false);
  });
});

// ──────────────────────────────────────────────
// fetchAndSyncTheme
// ──────────────────────────────────────────────

describe("fetchAndSyncTheme", () => {
  test("API からテーマを取得して適用する", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ theme: "dr" }) }),
    );

    const controller = makeController();
    const syncSpy = vi.spyOn(controller, "syncRadioFromThemeCode");
    const applySpy = vi.spyOn(controller, "applyThemeFromCode");

    await controller.fetchAndSyncTheme();

    expect(syncSpy).toHaveBeenCalledWith("dr");
    expect(applySpy).toHaveBeenCalledWith("dr");
  });

  test("API エラー時に syncRadio と applyThemeFromCookie にフォールバックする", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 500 }));

    cookieReadValue = "ct=li";
    const controller = makeController();
    const syncSpy = vi.spyOn(controller, "syncRadio");

    await controller.fetchAndSyncTheme();

    expect(syncSpy).toHaveBeenCalled();
    expect(documentMock.documentElement.dataset.theme).toBe("light");
  });

  test("fetch 例外時に syncRadio と applyThemeFromCookie にフォールバックする", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("Network error")));

    cookieReadValue = "ct=dr";
    const controller = makeController();
    const syncSpy = vi.spyOn(controller, "syncRadio");

    await controller.fetchAndSyncTheme();

    expect(syncSpy).toHaveBeenCalled();
    expect(documentMock.documentElement.dataset.theme).toBe("dark");
  });
});

// ──────────────────────────────────────────────
// syncRadioFromThemeCode
// ──────────────────────────────────────────────

describe("syncRadioFromThemeCode", () => {
  test('themeCode "dr" → radio[value="dark"] をチェックする', () => {
    const radio = { checked: false };
    const controller = makeController();
    controller.element.querySelector.mockReturnValue(radio);
    controller.syncRadioFromThemeCode("dr");
    expect(controller.element.querySelector).toHaveBeenCalledWith('input[value="dark"]');
    expect(radio.checked).toBe(true);
  });

  test("不明な themeCode は system にフォールバックする", () => {
    const radio = { checked: false };
    const controller = makeController();
    controller.element.querySelector.mockReturnValue(radio);
    controller.syncRadioFromThemeCode("unknown");
    expect(controller.element.querySelector).toHaveBeenCalledWith('input[value="system"]');
    expect(radio.checked).toBe(true);
  });

  test("対応する radio がない場合はエラーにならない", () => {
    const controller = makeController();
    controller.element.querySelector.mockReturnValue(null);
    expect(() => controller.syncRadioFromThemeCode("li")).not.toThrow();
  });
});

// ──────────────────────────────────────────────
// applyThemeFromCode
// ──────────────────────────────────────────────

describe("applyThemeFromCode", () => {
  test('themeCode "li" → light テーマを適用する', () => {
    const controller = makeController();
    controller.applyThemeFromCode("li");
    expect(documentMock.documentElement.dataset.theme).toBe("light");
    expect(classListMock.has("theme-light")).toBe(true);
  });

  test('themeCode "sy" → system テーマを適用する', () => {
    windowMock.matchMedia.mockReturnValue({ matches: false, addEventListener: vi.fn() });
    const controller = makeController();
    controller.applyThemeFromCode("sy");
    expect(documentMock.documentElement.dataset.theme).toBe("system");
    expect(classListMock.has("theme-system")).toBe(true);
  });

  test("不明な themeCode は system にフォールバックする", () => {
    windowMock.matchMedia.mockReturnValue({ matches: false, addEventListener: vi.fn() });
    const controller = makeController();
    controller.applyThemeFromCode("unknown");
    expect(documentMock.documentElement.dataset.theme).toBe("system");
  });

  test("js-theme-cookie-value 要素がある場合、テーマ値を設定する", () => {
    const valueEl = { textContent: "" };
    documentMock.querySelector.mockReturnValue(valueEl);
    const controller = makeController();
    controller.applyThemeFromCode("dr");
    expect(documentMock.querySelector).toHaveBeenCalledWith("#js-theme-cookie-value");
    expect(valueEl.textContent).toBe("dark");
  });
});
