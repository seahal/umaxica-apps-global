import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, describe, expect, it, vi } from "vitest";

// Unlike preference_screens.test.tsx (static markup only), these tests mount the components and
// fire real DOM events to exercise the onChange/onSubmit handlers - the branches static rendering
// cannot reach.
const patch = vi.fn();
const deleteRequest = vi.fn();

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { patch, delete: deleteRequest },
  usePage: () => ({ props: {} }),
}));

const { default: PreferenceSelect } = await import("@/features/preferences/PreferenceSelect");
const { default: PreferenceCookie } = await import("@/features/preferences/PreferenceCookie");
const { default: PreferenceCustomization } =
  await import("@/features/preferences/PreferenceCustomization");

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
    title: "地域と言語の設定",
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
      expect.objectContaining({ onStart: expect.any(Function), onFinish: expect.any(Function) }),
    );

    const [[, , options]] = patch.mock.calls;

    act(() => {
      options.onStart();
    });
    expect(container.querySelector("button")?.textContent).toBe("送信中");

    act(() => {
      options.onFinish();
    });
    expect(container.querySelector("button")?.textContent).toBe("更新");
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
      expect.objectContaining({ onStart: expect.any(Function), onFinish: expect.any(Function) }),
    );

    const [[, , options]] = patch.mock.calls;

    act(() => {
      options.onStart();
    });
    expect(container.querySelector("button")?.textContent).toBe("送信中");

    act(() => {
      options.onFinish();
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

    act(() => {
      checkbox.click();
    });
    expect(checkbox.checked).toBe(true);

    const form = container.querySelector<HTMLFormElement>("form")!;

    act(() => {
      form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(deleteRequest).toHaveBeenCalledWith(
      "/preference/customization?ri=jp",
      { confirm_reset: "1" },
      expect.objectContaining({ onStart: expect.any(Function), onFinish: expect.any(Function) }),
    );

    const [[, , options]] = deleteRequest.mock.calls;

    act(() => {
      options.onStart();
    });
    expect(container.querySelector("button")?.textContent).toBe("送信中");

    act(() => {
      options.onFinish();
    });
    expect(container.querySelector("button")?.textContent).toBe("リセット");
  });
});
