import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, test, vi } from "vitest";

import type { SurfaceChrome } from "@/types/inertia";

// The layout renders only what SurfaceChrome assembled on the server, so the page object is the
// single input. The chrome components have their own specs; here they are replaced by markers so
// the layout's own structure is what is asserted.
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
  return renderToStaticMarkup(
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
    const html = render(minimalChrome);

    expect(html).toContain('<main id="main"><p>page body</p></main>');
  });

  test("renders the brand, surface and copyright the server resolved", () => {
    const html = render(minimalChrome);

    expect(html).toContain('href="https://umaxica.app/"');
    expect(html).toContain("Umaxica");
    expect(html).toContain("(app)");
    expect(html).toContain("(c) Umaxica");
  });

  test("renders the family label only when the surface carries one", () => {
    expect(render(minimalChrome)).not.toContain("Base");
    expect(render({ ...minimalChrome, family_label: "Base" })).toContain("Base");
  });

  test("renders the chrome components with the controls the server assembled", () => {
    const html = render(minimalChrome);

    expect(html).toContain("cookie-controls-title");
    expect(html).toContain("theme-controls-title");
    expect(html).toContain('aria-label="Preferences"');
  });

  test("omits the banner, primary navigation and footer navigation when absent", () => {
    const html = render(minimalChrome);

    expect(html).not.toContain('aria-label="banner"');
    expect(html).not.toContain('aria-label="Primary"');
    expect(html).not.toContain('aria-label="Footer"');
  });

  test("renders the banner with its optional title", () => {
    const withTitle = render({
      ...minimalChrome,
      banner: { title: "メンテナンス", body: "停止予定があります。" },
    });

    expect(withTitle).toContain('aria-label="banner"');
    expect(withTitle).toContain("<h2>メンテナンス</h2>");
    expect(withTitle).toContain("停止予定があります。");

    const withoutTitle = render({
      ...minimalChrome,
      banner: { title: null, body: "本文のみ" },
    });

    expect(withoutTitle).toContain("本文のみ");
    expect(withoutTitle).not.toContain("<h2>");
  });

  // Navigation targets cross hosts, so they stay document visits rather than Inertia visits.
  test("renders navigation links as plain anchors", () => {
    const html = render({
      ...minimalChrome,
      primary_navigation: [{ label: "ホーム", href: "https://umaxica.app/" }],
      footer_navigation: [{ label: "会社概要", href: "https://umaxica.com/about" }],
    });

    expect(html).toContain('aria-label="Primary"');
    expect(html).toContain('<a href="https://umaxica.app/">ホーム</a>');
    expect(html).toContain('aria-label="Footer"');
    expect(html).toContain('<a href="https://umaxica.com/about">会社概要</a>');
  });
});
