import { beforeEach, describe, expect, test, vi } from "vitest";

vi.mock("@hotwired/stimulus", () => ({
  Controller: class {
    dispatch = vi.fn();
  },
}));

const { default: CookieBannerController } =
  await import("../../src/controllers/cookie_banner_controller.js");

function cookieFormFields({ checked }) {
  return {
    consented: { checked, dispatchEvent: vi.fn() },
    functional: { checked, dispatchEvent: vi.fn() },
    performant: { checked, dispatchEvent: vi.fn() },
    targetable: { checked, dispatchEvent: vi.fn() },
  };
}

function cookieFormFor(fields) {
  return {
    querySelector: vi.fn((selector) => {
      const match = selector.match(/preference_cookie\[(.+?)\]/);
      return match ? fields[match[1]] : null;
    }),
  };
}

describe("CookieBannerController", () => {
  let controller;
  let element;
  let cookieForm = null;

  beforeEach(() => {
    element = { remove: vi.fn() };
    controller = new CookieBannerController();
    controller.element = element;

    cookieForm = null;
    vi.stubGlobal("document", {
      querySelector: vi.fn((selector) => {
        if (selector === 'meta[name="csrf-token"]') {
          return { content: "csrf-token" };
        }
        if (selector === "[data-controller~='cookie-toggle'] form") {
          return cookieForm;
        }
        return null;
      }),
    });
    vi.stubGlobal("window", {
      location: {
        assign: vi.fn(),
        origin: "http://localhost:3000",
        search: "?ct=dr&lx=en&ri=us&ri=jp&rt=ignored&tz=asia/tokyo",
      },
      history: { pushState: vi.fn() },
    });
    vi.stubGlobal("fetch", vi.fn());
  });

  test("connect calls checkConsentState", () => {
    const spy = vi.spyOn(controller, "checkConsentState");
    controller.connect();
    expect(spy).toHaveBeenCalled();
  });

  describe("connect", () => {
    test("removes the banner when the API reports consent", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ consented: true }) }),
      );

      await controller.checkConsentState();
      expect(element.remove).toHaveBeenCalled();
    });

    test("keeps the banner when fetch fails", async () => {
      vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("Network error")));

      await controller.checkConsentState();
      expect(element.remove).not.toHaveBeenCalled();
    });

    test("keeps the banner when consent is false", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ consented: false }) }),
      );

      await controller.checkConsentState();
      expect(element.remove).not.toHaveBeenCalled();
    });

    test("keeps the banner when fetch fails repeatedly", async () => {
      vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("Network error")));

      await controller.checkConsentState();
      expect(element.remove).not.toHaveBeenCalled();
    });
  });

  describe("actions", () => {
    let event;
    beforeEach(() => {
      event = { preventDefault: vi.fn() };
    });

    test("invisible removes the banner", () => {
      controller.invisible(event);
      expect(event.preventDefault).toHaveBeenCalled();
      expect(element.remove).toHaveBeenCalled();
    });

    test("accept sends consent to the server, syncs the form, and removes the banner", async () => {
      const fields = cookieFormFields({ checked: false });
      cookieForm = cookieFormFor(fields);
      vi.stubGlobal(
        "fetch",
        vi.fn().mockResolvedValue({
          ok: true,
          json: () =>
            Promise.resolve({
              consented: true,
              functional: true,
              performant: true,
              targetable: true,
            }),
        }),
      );

      controller.accept(event);
      expect(event.preventDefault).toHaveBeenCalled();

      await vi.waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          "http://localhost:3000/web/v0/cookie?ri=us&lx=en&ct=dr&tz=asia%2Ftokyo",
          {
            method: "PATCH",
            headers: {
              Accept: "application/json",
              "Content-Type": "application/json",
              "X-CSRF-Token": "csrf-token",
            },
            body: JSON.stringify({
              cookie: {
                consented: true,
                functional: true,
                performant: true,
                targetable: true,
              },
            }),
          },
        );
        expect(fields.consented.checked).toBe(true);
        expect(fields.functional.checked).toBe(true);
        expect(fields.performant.checked).toBe(true);
        expect(fields.targetable.checked).toBe(true);
        expect(element.remove).toHaveBeenCalled();
      });
    });

    test("reject sends refusal to the server, syncs the form, and removes the banner", async () => {
      const fields = cookieFormFields({ checked: false });
      fields.consented.checked = true;
      cookieForm = cookieFormFor(fields);
      vi.stubGlobal(
        "fetch",
        vi.fn().mockResolvedValue({
          ok: true,
          json: () =>
            Promise.resolve({
              consented: true,
              functional: false,
              performant: false,
              targetable: false,
            }),
        }),
      );

      controller.reject(event);
      expect(event.preventDefault).toHaveBeenCalled();

      await vi.waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          "http://localhost:3000/web/v0/cookie?ri=us&lx=en&ct=dr&tz=asia%2Ftokyo",
          {
            method: "PATCH",
            headers: {
              Accept: "application/json",
              "Content-Type": "application/json",
              "X-CSRF-Token": "csrf-token",
            },
            body: JSON.stringify({
              cookie: {
                consented: true,
                functional: false,
                performant: false,
                targetable: false,
              },
            }),
          },
        );
        expect(fields.consented.checked).toBe(true);
        expect(fields.functional.checked).toBe(false);
        expect(fields.performant.checked).toBe(false);
        expect(fields.targetable.checked).toBe(false);
        expect(element.remove).toHaveBeenCalled();
      });
    });

    test("reject keeps the banner when the server update fails", async () => {
      vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 500 }));

      controller.reject(event);
      expect(event.preventDefault).toHaveBeenCalled();

      await vi.waitFor(() => {
        expect(fetch).toHaveBeenCalled();
      });
      expect(element.remove).not.toHaveBeenCalled();
    });

    test("syncCookieFormConsent updates cookie edit form checkboxes", () => {
      const fields = cookieFormFields({ checked: false });
      cookieForm = cookieFormFor(fields);

      controller.syncCookieFormConsent({
        consented: true,
        functional: true,
        performant: true,
        targetable: true,
      });

      expect(fields.consented.checked).toBe(true);
      expect(fields.functional.checked).toBe(true);
      expect(fields.performant.checked).toBe(true);
      expect(fields.targetable.checked).toBe(true);
    });

    test("syncCookieFormConsent does nothing when no cookie-toggle form exists", () => {
      controller.syncCookieFormConsent({ consented: true });
      expect(element.remove).not.toHaveBeenCalled();
    });

    test("syncCookieFormConsent skips fields missing from consentState", () => {
      const fields = cookieFormFields({ checked: false });
      cookieForm = cookieFormFor(fields);

      controller.syncCookieFormConsent({ consented: true });

      expect(fields.functional.checked).toBe(false);
      expect(fields.performant.checked).toBe(false);
      expect(fields.targetable.checked).toBe(false);
    });

    test("syncCookieFormConsent applies reject-all response with only consent true", () => {
      const fields = cookieFormFields({ checked: false });
      cookieForm = cookieFormFor(fields);

      controller.syncCookieFormConsent({
        consented: true,
        functional: false,
        performant: false,
        targetable: false,
      });

      expect(fields.consented.checked).toBe(true);
      expect(fields.functional.checked).toBe(false);
      expect(fields.performant.checked).toBe(false);
      expect(fields.targetable.checked).toBe(false);
    });

    test("openSettings navigates to the settings URL when present", () => {
      controller.hasSettingsUrlValue = true;
      controller.settingsUrlValue = "/preference/cookie/edit?ri=jp";

      controller.openSettings(event);

      expect(event.preventDefault).toHaveBeenCalled();
      expect(window.location.assign).toHaveBeenCalledWith("/preference/cookie/edit?ri=jp");
      expect(controller.dispatch).not.toHaveBeenCalled();
    });

    test("openSettings falls back to null without a settings URL", () => {
      controller.hasSettingsUrlValue = false;

      controller.openSettings(event);

      expect(event.preventDefault).toHaveBeenCalled();
      expect(controller.dispatch).toHaveBeenCalledWith("open-settings", {
        detail: { consent: null },
      });
    });

    test("fetchCookieConsent raises when the response is not OK", async () => {
      vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 500 }));
      await expect(controller.fetchCookieConsent()).rejects.toThrow("HTTP error! status: 500");
    });

    test("cookieEndpointUrl normalizes query parameters sent to the API", () => {
      expect(controller.cookieEndpointUrl()).toBe(
        "http://localhost:3000/web/v0/cookie?ri=us&lx=en&ct=dr&tz=asia%2Ftokyo",
      );
    });

    test("csrfToken: meta タグがない場合は空文字列を返す", () => {
      vi.stubGlobal("document", {
        querySelector: vi.fn(() => null),
      });
      expect(controller.csrfToken()).toBe("");
    });

    test("accept 失敗時に dispatchConsentError が呼ばれる", async () => {
      vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 500 }));
      const dispatchSpy = vi.spyOn(controller, "dispatch");

      controller.accept(event);

      await vi.waitFor(() => {
        expect(dispatchSpy).toHaveBeenCalledWith("error", {
          detail: { message: "Cookie consent update failed", error: expect.any(Error) },
        });
      });
    });

    test("syncCookieFormConsent: checkbox がない場合はスキップする", () => {
      const fields = cookieFormFields({ checked: false });
      cookieForm = cookieFormFor(fields);
      const selectors = {
        'meta[name="csrf-token"]': { content: "csrf-token" },
        "[data-controller~='cookie-toggle'] form": cookieForm,
      };
      vi.stubGlobal("document", {
        querySelector: vi.fn((selector) => selectors[selector]),
      });

      // Override to return null for the specific checkbox query
      cookieForm.querySelector = vi.fn(() => null);

      // Should not throw when checkbox is not found
      controller.syncCookieFormConsent({
        consented: true,
        functional: true,
        performant: true,
        targetable: true,
      });
    });
  });
});
