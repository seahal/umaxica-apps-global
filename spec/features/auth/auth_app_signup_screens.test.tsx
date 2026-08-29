import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it } from "vitest";

import { csrfToken } from "@/features/auth/signup/csrf";

// The auth/app sign-up entry, checkpoint and social-confirmation screens. `src/pages/auth/app`
// resolves these straight from `@/features/auth/signup`, so they are exercised here through the
// feature components they re-export: every string and URL arrives finished from the server, so the
// assertions are about what the page draws from its props, not about how it computes anything.
const { default: SignUpMethodChoice } = await import("@/features/auth/signup/SignUpMethodChoice");
const { default: SocialSignUpConfirmation } =
  await import("@/features/auth/signup/SocialSignUpConfirmation");

const turnstile = {
  site_key: "site-key",
  mode: "render" as const,
  action: null,
  cdata: null,
};

describe("auth/app sign-up method choice", () => {
  const props = {
    title: "登録方法を選択",
    suspended_notice: null,
    methods: [{ key: "email", label: "メールアドレスで登録", href: "/sign/up/email?ri=jp" }],
    social_providers: [
      { provider: "google", label: "Googleで登録", url: "/sign/up/social/google?ri=jp" },
      {
        provider: "apple",
        label: "Appleで登録",
        url: "/sign/up/social/apple?ri=jp",
        apple_logos: { white: "/apple-white.svg", black: "/apple-black.svg" },
      },
      { provider: "github", label: "GitHubで登録", url: "/sign/up/social/github?ri=jp" },
    ],
    links: [{ key: "sign_in", label: "ログイン", href: "/sign/in?ri=jp" }],
  };

  it("draws every registration method and social provider the server offered", () => {
    const markup = renderToStaticMarkup(<SignUpMethodChoice {...props} />);

    expect(markup).toMatch(/<h1[^>]*>登録方法を選択<\/h1>/u);
    expect(markup).toMatch(/<a href="\/sign\/up\/email\?ri=jp"[^>]*>メールアドレスで登録<\/a>/u);
    expect(markup).toContain('aria-label="Sign in with Google"');
    expect(markup).toContain('action="/sign/up/social/apple?ri=jp"');
    expect(markup).toContain("/apple-white.svg");
    expect(markup).toContain("/apple-black.svg");
    expect(markup).toContain('value="GitHubで登録"');
    expect(markup).toMatch(/<a href="\/sign\/in\?ri=jp"[^>]*>ログイン<\/a>/u);
  });

  it("draws an Apple button with no artwork when none is in the repository", () => {
    const markup = renderToStaticMarkup(
      <SignUpMethodChoice
        {...props}
        social_providers={[
          { provider: "apple", label: "Appleで登録", url: "/sign/up/social/apple?ri=jp" },
        ]}
      />,
    );

    expect(markup).toContain("Appleで登録");
    expect(markup).not.toContain("apple-logo");
  });

  it("shows the suspension notice instead of any entry point while the kill switch is on", () => {
    const markup = renderToStaticMarkup(
      <SignUpMethodChoice
        {...props}
        suspended_notice="現在、新規登録を停止しています"
      />,
    );

    expect(markup).toContain('data-test-id="sign-up-suspended"');
    expect(markup).toContain("現在、新規登録を停止しています");
    expect(markup).not.toContain("メールアドレスで登録");
  });
});

describe("csrfToken", () => {
  afterEach(() => {
    document.head.innerHTML = "";
  });

  it("reads the token from the surface shell's meta tag", () => {
    document.head.innerHTML = '<meta name="csrf-token" content="a-token">';

    expect(csrfToken()).toBe("a-token");
  });

  it("answers an empty string when rendered outside a browser document", () => {
    const originalDocument = globalThis.document;
    // @ts-expect-error -- simulating the server-rendering environment this guard exists for.
    delete globalThis.document;

    try {
      expect(csrfToken()).toBe("");
    } finally {
      globalThis.document = originalDocument;
    }
  });
});

describe("auth/app social sign-up confirmation", () => {
  const props = {
    title: "新しいアカウントを作成しますか？",
    unregistered: "この外部アカウントは登録されていません",
    create_identity: "新しいアカウントを作成します",
    no_merge: "既存のアカウントとは統合されません",
    cancel_if_wrong: "心当たりがない場合はキャンセルしてください",
    confirm_label: "上記に同意します",
    submit_label: "作成する",
    cancel_label: "キャンセル",
    action: "/sign/up/check/social/confirmation?ri=jp",
    checkpoint_version: 2,
    turnstile,
  };

  it("posts the confirmation as a PATCH and the cancellation as a DELETE, to the same endpoint", () => {
    const markup = renderToStaticMarkup(<SocialSignUpConfirmation {...props} />);

    expect(markup).toMatch(/<h1[^>]*>新しいアカウントを作成しますか？<\/h1>/u);
    expect(markup.match(/action="\/sign\/up\/check\/social\/confirmation\?ri=jp"/gu)).toHaveLength(
      2,
    );
    expect(markup).toContain('name="_method" value="patch"');
    expect(markup).toContain('name="_method" value="delete"');
    expect(markup).toContain('name="checkpoint_version" value="2"');
    expect(markup).toContain('name="confirm_new_social_identity"');
  });
});
