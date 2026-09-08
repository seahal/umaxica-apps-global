import type { router as inertiaRouter } from "@inertiajs/react";
import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, describe, expect, it, vi } from "vitest";

import { A_FUNCTION, containing } from "../../support/matchers";
import { present } from "../../support/present";
import { finishVisit, startVisit } from "../../support/visit";

// Unlike preference_screens.test.tsx (static markup only), these tests mount the components and
// fire real DOM events to exercise the onChange/onSubmit handlers - the branches static rendering
// cannot reach.
// Typed from the adapter's own signatures, so an assertion on a recorded call is checked against
// the arguments Inertia actually passes rather than against `any`.
const patch = vi.fn<typeof inertiaRouter.patch>();
const deleteRequest = vi.fn<typeof inertiaRouter.delete>();

vi.mock("@/features/turnstile/TurnstileWidget", () => ({
  default: ({ onToken }: { onToken?: (token: string) => void }) => (
    <button
      type="button"
      onClick={() => onToken?.("turnstile-token")}
    >
      challenge
    </button>
  ),
}));

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { patch, delete: deleteRequest },
  // The server runs with `always_include_errors_hash`, so `errors` is present on every response;
  // a mock that omits it would let a component read `undefined` that production never sees.
  usePage: () => ({ props: { errors: {} } }),
}));

const { default: PreferenceSelect } = await import("@/features/preferences/PreferenceSelect");
const { default: PreferenceCookie } = await import("@/features/preferences/PreferenceCookie");
const { default: PreferenceCustomization } =
  await import("@/features/preferences/PreferenceCustomization");
const { default: PreferenceEmailUnsubscribe } =
  await import("@/features/preferences/PreferenceEmailUnsubscribe");

let container: HTMLDivElement;
let root: Root;

const mount = (element: React.ReactElement) => {
  container = document.createElement("div");
  document.body.append(container);
  root = createRoot(container);
  act(() => {
    root.render(element);
  });
};

afterEach(() => {
  act(() => {
    root.unmount();
  });
  container.remove();
  patch.mockClear();
  deleteRequest.mockClear();
});

describe("PreferenceSelect interaction", () => {
  const backLink = { label: "もどる", href: "/preference?ri=jp" };
  const props = {
    screen: "region",
    title: "地域設定",
    description: "地域を選びます。",
    back_link: backLink,
    form: {
      action: "/preference/region?ri=jp",
      method: "patch",
      scope: "preference_region",
      field: "option_id",
      label: "地域",
      value: 2,
      choices: [
        { label: "日本", value: 2 },
        { label: "アメリカ合衆国 (USA)", value: 1 },
      ],
      submit_label: "更新",
      submitting_label: "送信中",
    },
    region_link: null,
    linked_screens: [],
  };

  it("submits the selected value and toggles the processing label", () => {
    mount(<PreferenceSelect {...props} />);

    const select = container.querySelector<HTMLSelectElement>("select")!;

    act(() => {
      select.value = "1";
      select.dispatchEvent(new Event("change", { bubbles: true }));
    });
    expect(select.value).toBe("1");

    const form = container.querySelector<HTMLFormElement>("form")!;

    act(() => {
      form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(patch).toHaveBeenCalledWith(
      "/preference/region?ri=jp",
      { preference_region: { option_id: "1" } },
      containing({ onStart: A_FUNCTION, onFinish: A_FUNCTION }),
    );

    const [, , options] = present(patch.mock.calls[0], "the first router.patch call");
    // `button` alone is ambiguous now: `Select` renders its own trigger button before the
    // submit button, so the submit control is selected by its `type` instead.
    const submit = container.querySelector<HTMLButtonElement>('button[type="submit"]')!;

    act(() => {
      startVisit(options);
    });
    expect(submit.textContent).toBe("送信中");

    act(() => {
      finishVisit(options);
    });
    expect(submit.textContent).toBe("更新");
  });
});

describe("PreferenceCookie interaction", () => {
  const props = {
    screen: "cookie",
    title: "クッキー設定",
    description: "同意する範囲を選びます。",
    back_link: { label: "もどる", href: "/preference?ri=jp" },
    form: {
      action: "/preference/cookie?ri=jp",
      method: "patch",
      scope: "preference_cookie",
      necessary_label: "必須クッキー",
      categories: [{ key: "functional", label: "機能", value: false }],
      submit_label: "更新",
      submitting_label: "送信中",
    },
  };

  it("toggles a category and submits the updated selection", () => {
    mount(<PreferenceCookie {...props} />);

    const checkbox = container.querySelector<HTMLInputElement>(
      "input[name='preference_cookie[functional]']",
    )!;

    act(() => {
      checkbox.click();
    });
    expect(checkbox.checked).toBe(true);

    const form = container.querySelector<HTMLFormElement>("form")!;

    act(() => {
      form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(patch).toHaveBeenCalledWith(
      "/preference/cookie?ri=jp",
      { preference_cookie: { functional: true } },
      containing({ onStart: A_FUNCTION, onFinish: A_FUNCTION }),
    );

    const [, , options] = present(patch.mock.calls[0], "the first router.patch call");

    act(() => {
      startVisit(options);
    });
    expect(container.querySelector("button")?.textContent).toBe("送信中");

    act(() => {
      finishVisit(options);
    });
    expect(container.querySelector("button")?.textContent).toBe("更新");
  });
});

describe("PreferenceCustomization interaction", () => {
  const props = {
    screen: "customization",
    title: "設定のリセット",
    description: "すべての設定を初期化します。",
    back_link: { label: "もどる", href: "/preference?ri=jp" },
    form: {
      action: "/preference/customization?ri=jp",
      method: "delete",
      field: "confirm_reset",
      label: "リセットに同意する",
      value: false,
      submit_label: "リセット",
      submitting_label: "送信中",
    },
  };

  it("requires confirmation to be checked before submitting the reset", () => {
    mount(<PreferenceCustomization {...props} />);

    const checkbox = container.querySelector<HTMLInputElement>("input[name='confirm_reset']")!;
    const form = container.querySelector<HTMLFormElement>("form")!;

    act(() => {
      form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });
    expect(deleteRequest).toHaveBeenCalledWith(
      "/preference/customization?ri=jp",
      containing({ data: { confirm_reset: "" } }),
    );
    deleteRequest.mockClear();

    act(() => {
      checkbox.click();
    });
    expect(checkbox.checked).toBe(true);

    act(() => {
      form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(deleteRequest).toHaveBeenCalledWith(
      "/preference/customization?ri=jp",
      containing({
        data: { confirm_reset: "1" },
        onStart: A_FUNCTION,
        onFinish: A_FUNCTION,
      }),
    );

    const [, options] = present(deleteRequest.mock.calls[0], "the first router.delete call");

    act(() => {
      startVisit(options);
    });
    expect(container.querySelector("button")?.textContent).toBe("送信中");

    act(() => {
      finishVisit(options);
    });
    expect(container.querySelector("button")?.textContent).toBe("リセット");
  });
});

describe("PreferenceEmailUnsubscribe interaction", () => {
  const form = {
    action: "/preference/emails?token=abc",
    token: "signed-token",
    submit_label: "配信停止",
    turnstile_site_key: "site-key",
  };

  it("deletes with the signed token and the challenge response", () => {
    mount(
      <PreferenceEmailUnsubscribe
        title="配信停止"
        heading="配信を停止します"
        promotional
        description="確認してください"
        form={form}
      />,
    );

    const [challenge] = container.querySelectorAll("button");
    act(() => {
      challenge?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
    });

    const formElement = container.querySelector<HTMLFormElement>("form")!;
    act(() => {
      formElement.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(deleteRequest).toHaveBeenCalledWith("/preference/emails?token=abc", {
      data: { token: "signed-token", "cf-turnstile-response": "turnstile-token" },
    });
  });

  it("omits the form when promotional mail is already off", () => {
    mount(
      <PreferenceEmailUnsubscribe
        title="配信停止"
        heading="配信を停止します"
        promotional={false}
        description="確認してください"
        form={form}
      />,
    );

    expect(container.querySelector("form")).toBeNull();
  });

  it("omits the form when the server sent no token", () => {
    mount(
      <PreferenceEmailUnsubscribe
        title="配信停止"
        heading="配信を停止します"
        promotional
        description="確認してください"
        form={null}
      />,
    );

    expect(container.querySelector("form")).toBeNull();
  });
});
