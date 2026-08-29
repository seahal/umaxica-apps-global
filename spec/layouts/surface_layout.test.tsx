import { render as renderTree, screen, within } from "@testing-library/react";
import { afterEach, describe, expect, test, vi } from "vitest";

import type { SurfaceChrome } from "@/types/inertia";

// The layout renders only what SurfaceChrome assembled on the server, so the page object is the
// single input. The chrome components have their own specs; here they are replaced by markers so
// the layout's own structure is what is asserted.
//
// The assertions query by role and accessible name rather than by markup. The layout's contract is
// its document structure — landmarks, headings, lists and link targets — and that has to survive
// the styling it carries, which exact-markup assertions did not.
vi.mock("@inertiajs/react", () => ({
  usePage: () => page,
}));

vi.mock("@/components/chrome/CookieBanner", () => ({
  default: ({ controls }: { controls: { title: string } }) => (
    <div data-testid="cookie-banner">{controls.title}</div>
  ),
}));

vi.mock("@/components/chrome/ThemeControls", () => ({
  default: ({ controls }: { controls: { title: string } }) => (
    <div data-testid="theme-controls">{controls.title}</div>
  ),
}));

const { default: SurfaceLayout } = await import("@/layouts/SurfaceLayout");

const cookieControls = {
  scope: "cookie",
  settings_url: "/preference/cookie/edit",
  title: "cookie-controls-title",
  description_html: "cookie description",
  close_button: "閉じる",
  reject_all: "すべて拒否",
  open_settings: "設定を開く",
  accept_all: "すべて許可",
};

const themeControls = {
  hidden: false,
  title: "theme-controls-title",
  description: "テーマを選びます。",
  options: { system: "システム", light: "ライト", dark: "ダーク" },
};

const minimalChrome: SurfaceChrome = {
  family_label: null,
  surface: "app",
  brand: { name: "Umaxica", href: "https://umaxica.app/" },
  banner: null,
  primary_navigation: null,
  footer_navigation: null,
  cookie_controls: cookieControls,
  theme_controls: themeControls,
  copyright: "(c) Umaxica",
};

const page = { props: { chrome: minimalChrome, errors: {} } };

const render = (chrome: SurfaceChrome) => {
  page.props.chrome = chrome;
  return renderTree(
    <SurfaceLayout>
      <p>page body</p>
    </SurfaceLayout>,
  );
};

afterEach(() => {
  page.props.chrome = minimalChrome;
});

describe("SurfaceLayout", () => {
  test("renders the page inside the main landmark", () => {
    render(minimalChrome);

    const main = screen.getByRole("main");
    expect(main.id).toBe("main");
    expect(within(main).getByText("page body")).toBeTruthy();
  });

  test("renders the brand, surface and copyright the server resolved", () => {
    const { container } = render(minimalChrome);

    expect(screen.getByRole("link", { name: "Umaxica" }).getAttribute("href")).toBe(
      "https://umaxica.app/",
    );
    expect(container.textContent).toContain("(app)");
    expect(container.textContent).toContain("(c) Umaxica");
  });

  test("renders the family label only when the surface carries one", () => {
    expect(render(minimalChrome).container.textContent).not.toContain("Base");
    expect(render({ ...minimalChrome, family_label: "Base" }).container.textContent).toContain(
      "Base",
    );
  });

  test("renders the chrome components with the controls the server assembled", () => {
    render(minimalChrome);

    expect(screen.getByTestId("cookie-banner").textContent).toBe("cookie-controls-title");
    expect(screen.getByTestId("theme-controls").textContent).toBe("theme-controls-title");
    expect(screen.getByRole("complementary", { name: "Preferences" })).toBeTruthy();
  });

  test("omits the banner, primary navigation and footer navigation when absent", () => {
    render(minimalChrome);

    expect(screen.queryByRole("region", { name: "banner" })).toBeNull();
    expect(screen.queryByRole("navigation", { name: "Primary" })).toBeNull();
    expect(screen.queryByRole("navigation", { name: "Footer" })).toBeNull();
  });

  test("renders the banner with its title", () => {
    render({
      ...minimalChrome,
      banner: { title: "メンテナンス", body: "停止予定があります。" },
    });

    const banner = screen.getByRole("region", { name: "banner" });
    expect(within(banner).getByRole("heading", { name: "メンテナンス" })).toBeTruthy();
    expect(within(banner).getByText("停止予定があります。")).toBeTruthy();
  });

  test("renders a banner that carries no title without an empty heading", () => {
    render({ ...minimalChrome, banner: { title: null, body: "本文のみ" } });

    const banner = screen.getByRole("region", { name: "banner" });
    expect(within(banner).getByText("本文のみ")).toBeTruthy();
    expect(within(banner).queryByRole("heading")).toBeNull();
  });

  // Navigation targets cross hosts, so they stay document visits rather than Inertia visits.
  test("renders navigation links as plain anchors", () => {
    render({
      ...minimalChrome,
      primary_navigation: [{ label: "ホーム", href: "https://umaxica.app/" }],
      footer_navigation: [{ label: "会社概要", href: "https://umaxica.com/about" }],
    });

    const primary = screen.getByRole("navigation", { name: "Primary" });
    const home = within(primary).getByRole("link", { name: "ホーム" });
    expect(home.getAttribute("href")).toBe("https://umaxica.app/");
    // A document visit, so no Inertia interception marker.
    expect(Object.hasOwn(home.dataset, "inertia")).toBe(false);

    const footer = screen.getByRole("navigation", { name: "Footer" });
    expect(within(footer).getByRole("link", { name: "会社概要" }).getAttribute("href")).toBe(
      "https://umaxica.com/about",
    );
  });

  test("keeps the navigation links inside lists so they can be counted", () => {
    render({
      ...minimalChrome,
      primary_navigation: [
        { label: "ホーム", href: "https://umaxica.app/" },
        { label: "設定", href: "https://umaxica.app/settings" },
      ],
    });

    const primary = screen.getByRole("navigation", { name: "Primary" });
    expect(within(primary).getAllByRole("listitem")).toHaveLength(2);
  });

  test("renders neither the theme controls nor the cookie banner when the surface carries neither", () => {
    render({ ...minimalChrome, theme_controls: null, cookie_controls: null });

    expect(screen.queryByTestId("theme-controls")).toBeNull();
    expect(screen.queryByTestId("cookie-banner")).toBeNull();
  });
});
