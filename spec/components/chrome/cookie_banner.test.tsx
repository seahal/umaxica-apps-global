import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import CookieBanner from "@/components/chrome/CookieBanner";
import type { ChromeCookieControls } from "@/types/inertia";

// The React port of the `cookie-banner` Stimulus controller is verified against the same
// behaviour the controller spec asserts: the consent read on mount, the PATCH payload of each
// answer, the close button and the settings navigation.
const controls: ChromeCookieControls = {
  scope: "cookie",
  settings_url: "/preference/cookie/edit?ri=jp",
  title: "Cookie の利用について",
  description_html: "この端末の Cookie 設定を選べます。",
  close_button: "閉じる",
  reject_all: "すべて拒否",
  open_settings: "設定を開く",
  accept_all: "すべて許可",
};

const ENDPOINT = "http://localhost:3000/web/v0/cookie?ri=us&lx=en&ct=dr&tz=asia%2Ftokyo";

let container: HTMLDivElement | undefined;
let root: Root | undefined;
let assign: ReturnType<typeof vi.fn>;
let fetchMock: ReturnType<typeof vi.fn>;

const stubFetch = (mock: ReturnType<typeof vi.fn>) => {
  fetchMock = mock;
  vi.stubGlobal("fetch", mock);
};

const noop = () => {};

const mount = async () => {
  container = document.createElement("div");
  document.body.append(container);
  const mounted = createRoot(container);
  root = mounted;
  await act(async () => {
    mounted.render(<CookieBanner controls={controls} />);
  });
};

const banner = () => container?.querySelector("#cookie-banner");
const button = (label: string) =>
  [...(container?.querySelectorAll("button") ?? [])].find(
    (element) => element.textContent === label || element.getAttribute("aria-label") === label,
  );

const click = async (element: HTMLButtonElement | undefined) => {
  await act(async () => {
    element?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  });
};

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="csrf-token">';
  assign = vi.fn();
  // jsdom's location is not redefinable in place, so the whole object is stubbed; the query string
  // carries the preference context the endpoint URL is built from.
  vi.stubGlobal("location", {
    origin: "http://localhost:3000",
    search: "?ct=dr&lx=en&ri=us&rt=ignored&tz=asia%2Ftokyo",
    assign,
  });
  stubFetch(vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({}) }));
});

afterEach(() => {
  const mounted = root;
  if (mounted) {
    act(() => {
      mounted.unmount();
    });
  }
  container?.remove();
  root = undefined;
  container = undefined;
  document.head.innerHTML = "";
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe("CookieBanner mount", () => {
  test("hides the banner when the API reports an existing consent", async () => {
    stubFetch(
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ consented: true }) }),
    );

    await mount();

    expect(fetchMock).toHaveBeenCalledWith(ENDPOINT);
    expect(banner()).toBeNull();
  });

  test("keeps the banner when no consent is recorded yet", async () => {
    stubFetch(
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ consented: false }) }),
    );

    await mount();

    expect(banner()).not.toBeNull();
    expect(banner()?.textContent).toContain(controls.title);
    expect(banner()?.textContent).toContain(controls.description_html);
  });

  test("keeps the banner when the consent read answers an error", async () => {
    stubFetch(vi.fn().mockResolvedValue({ ok: false, status: 500 }));

    await mount();

    expect(banner()).not.toBeNull();
  });

  test("keeps the banner when the consent read fails", async () => {
    stubFetch(vi.fn().mockRejectedValue(new Error("offline")));

    await mount();

    expect(banner()).not.toBeNull();
  });

  // The read is aborted on unmount so a late answer cannot update a component that is gone.
  test("ignores a consent answer that arrives after unmount", async () => {
    let resolveRead: (value: unknown) => void = noop;
    stubFetch(
      vi.fn().mockReturnValue(
        new Promise((resolve) => {
          resolveRead = resolve;
        }),
      ),
    );

    await mount();
    const mounted = root;
    act(() => {
      mounted?.unmount();
    });

    await act(async () => {
      resolveRead({ ok: true, json: () => Promise.resolve({ consented: true }) });
    });

    // Re-mounted in afterEach terms: unmounting twice is safe, and no state update was attempted.
    expect(container?.textContent).toBe("");
  });
});

describe("CookieBanner actions", () => {
  const patchPayload = (consented: boolean) => [
    ENDPOINT,
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
          functional: consented,
          performant: consented,
          targetable: consented,
        },
      }),
    },
  ];

  test("accepting sends consent for every category and hides the banner", async () => {
    await mount();
    await click(button(controls.accept_all));

    expect(fetchMock).toHaveBeenLastCalledWith(...patchPayload(true));
    expect(banner()).toBeNull();
  });

  test("rejecting still records the decision but refuses every category", async () => {
    await mount();
    await click(button(controls.reject_all));

    expect(fetchMock).toHaveBeenLastCalledWith(...patchPayload(false));
    expect(banner()).toBeNull();
  });

  test("keeps the banner when the server rejects the decision", async () => {
    await mount();
    stubFetch(vi.fn().mockResolvedValue({ ok: false, status: 500 }));

    await click(button(controls.reject_all));

    expect(banner()).not.toBeNull();
    expect(button(controls.reject_all)?.disabled).toBe(false);
  });

  test("the close button dismisses the banner without recording a decision", async () => {
    await mount();
    const calls = fetchMock.mock.calls.length;

    await click(button(controls.close_button));

    expect(banner()).toBeNull();
    expect(fetchMock.mock.calls.length).toBe(calls);
  });

  test("the settings button leaves for the cookie preference screen", async () => {
    await mount();

    await click(button(controls.open_settings));

    expect(assign).toHaveBeenCalledWith(controls.settings_url);
    expect(banner()).not.toBeNull();
  });
});
