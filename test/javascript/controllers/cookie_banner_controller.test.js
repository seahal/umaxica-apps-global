import { beforeEach, describe, expect, test, vi } from "vite-plus/test";

vi.mock("@hotwired/stimulus", () => ({
  Controller: class {
    dispatch = vi.fn();
  },
}));

const { default: CookieBannerController } =
  await import("../../../app/javascript/controllers/cookie_banner_controller.js");

describe("CookieBannerController", () => {
  let controller;
  let element;
  let cookieValue = "";

  beforeEach(() => {
    element = { remove: vi.fn() };
    controller = new CookieBannerController();
    controller.element = element;

    cookieValue = "";
    vi.stubGlobal("document", {
      get cookie() {
        return cookieValue;
      },
      set cookie(val) {
        cookieValue = val;
      },
      querySelector: vi.fn().mockReturnValue({ content: "csrf-token" }),
    });

    window.history.pushState({}, "", "/preference/cookie/edit?ct=dr&lx=en&ri=us&tz=asia/tokyo");
    vi.stubGlobal("fetch", vi.fn());
  });

  test("connect: checkConsentState を呼ぶ", () => {
    const spy = vi.spyOn(controller, "checkConsentState");
    controller.connect();
    expect(spy).toHaveBeenCalled();
  });

  describe("connect", () => {
    test("同意済みの場合、要素を削除する (API)", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ consented: true }) }),
      );

      await controller.checkConsentState();
      expect(element.remove).toHaveBeenCalled();
    });

    test("同意済みの場合、要素を削除する (Cookie フォールバック)", async () => {
      vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("Network error")));
      cookieValue = "cookie_consent=accepted";

      await controller.checkConsentState();
      expect(element.remove).toHaveBeenCalled();
    });

    test("未同意の場合、要素を削除しない", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ consented: false }) }),
      );

      await controller.checkConsentState();
      expect(element.remove).not.toHaveBeenCalled();
    });

    test("fetch 失敗時に cookie がない場合、要素を削除しない", async () => {
      vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("Network error")));
      cookieValue = "other=value";

      await controller.checkConsentState();
      expect(element.remove).not.toHaveBeenCalled();
    });
  });

  describe("actions", () => {
    let event;
    beforeEach(() => {
      event = { preventDefault: vi.fn() };
    });

    test("invisible: 要素を削除する", () => {
      controller.invisible(event);
      expect(event.preventDefault).toHaveBeenCalled();
      expect(element.remove).toHaveBeenCalled();
    });

    test("accept: サーバに同意を送信してクッキーを設定し要素を削除する", async () => {
      vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: true }));

      controller.accept(event);
      expect(event.preventDefault).toHaveBeenCalled();

      await vi.waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          "http://localhost:3000/web/v0/cookie?ct=dr&lx=en&ri=us&tz=asia%2Ftokyo",
          {
            method: "PATCH",
            headers: {
              Accept: "application/json",
              "Content-Type": "application/json",
              "X-CSRF-Token": "csrf-token",
            },
            body: JSON.stringify({ consented: true }),
          },
        );
        expect(document.cookie).toContain("cookie_consent=accepted");
        expect(element.remove).toHaveBeenCalled();
      });
    });

    test("reject: サーバに拒否を送信してクッキーを設定し要素を削除する", async () => {
      vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: true }));

      controller.reject(event);
      expect(event.preventDefault).toHaveBeenCalled();

      await vi.waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          "http://localhost:3000/web/v0/cookie?ct=dr&lx=en&ri=us&tz=asia%2Ftokyo",
          {
            method: "PATCH",
            headers: {
              Accept: "application/json",
              "Content-Type": "application/json",
              "X-CSRF-Token": "csrf-token",
            },
            body: JSON.stringify({ consented: false }),
          },
        );
        expect(document.cookie).toContain("cookie_consent=rejected");
        expect(element.remove).toHaveBeenCalled();
      });
    });

    test("reject: サーバ更新に失敗した場合は要素を削除しない", async () => {
      vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 500 }));

      controller.reject(event);
      expect(event.preventDefault).toHaveBeenCalled();

      await vi.waitFor(() => {
        expect(fetch).toHaveBeenCalled();
      });
      expect(document.cookie).not.toContain("cookie_consent=rejected");
      expect(element.remove).not.toHaveBeenCalled();
    });

    test("openSettings: open-settings イベントをディスパッチする", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ consented: true }) }),
      );

      controller.openSettings(event);
      expect(event.preventDefault).toHaveBeenCalled();

      await vi.waitFor(() => {
        expect(controller.dispatch).toHaveBeenCalledWith("open-settings", {
          detail: { consent: { consented: true } },
        });
      });
    });

    test("openSettings: fetch 失敗時に cookie からフォールバックする", async () => {
      vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("Network error")));
      cookieValue = "cookie_consent=accepted";

      controller.openSettings(event);
      expect(event.preventDefault).toHaveBeenCalled();

      await vi.waitFor(() => {
        expect(controller.dispatch).toHaveBeenCalledWith("open-settings", {
          detail: { consent: "accepted" },
        });
      });
    });

    test("openSettings: fetch 失敗時に cookie もない場合は null をフォールバックする", async () => {
      vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("Network error")));
      cookieValue = "";

      controller.openSettings(event);
      expect(event.preventDefault).toHaveBeenCalled();

      await vi.waitFor(() => {
        expect(controller.dispatch).toHaveBeenCalledWith("open-settings", {
          detail: { consent: null },
        });
      });
    });

    test("normalizeConsentValue: 空値は null を返す", () => {
      expect(controller.normalizeConsentValue(null)).toBeNull();
      expect(controller.normalizeConsentValue(undefined)).toBeNull();
      expect(controller.normalizeConsentValue("")).toBeNull();
    });

    test("normalizeConsentValue: 小文字に正規化する", () => {
      expect(controller.normalizeConsentValue("Accepted")).toBe("accepted");
    });

    test("fetchCookieConsent: レスポンスが OK でないときエラーを投げる", async () => {
      vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 500 }));
      await expect(controller.fetchCookieConsent()).rejects.toThrow("HTTP error! status: 500");
    });

    test("getCookieConsent: 一致しない cookie は null を返す", () => {
      cookieValue = "other=value";
      expect(controller.getCookieConsent()).toBeNull();
    });

    test("hasCookieConsent: 同意済みの場合 true", () => {
      cookieValue = "cookie_consent=accepted";
      expect(controller.hasCookieConsent()).toBe(true);
    });

    test("hasCookieConsent: 未同意の場合 false", () => {
      cookieValue = "";
      expect(controller.hasCookieConsent()).toBe(false);
    });
  });
});
