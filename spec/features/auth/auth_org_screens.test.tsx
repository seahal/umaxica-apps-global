import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// The auth/org screens the surface resolves from `src/pages/auth/org`. Every string and every URL
// arrives finished from the server, so the assertions are about what the page draws from its props,
// not about how it computes anything.
//
// The Cloudflare challenge and the passkey ceremonies do not exist outside a booted application, so
// they are stubbed to what they render; each ceremony is covered by its own spec.
vi.mock("@/features/turnstile/TurnstileWidget", () => ({
  default: ({ site_key: siteKey }: { site_key: string }) => (
    <div data-turnstile-site-key={siteKey} />
  ),
}));

vi.mock("@/features/auth/passkeys/PasskeyAuthenticationPanel", () => ({
  default: ({ submit_label: submitLabel }: { submit_label: string }) => (
    <button type="button">{submitLabel}</button>
  ),
}));

vi.mock("@/features/auth/passkeys/PasskeyRegistrationPanel", () => ({
  default: ({ submit_label: submitLabel }: { submit_label: string }) => (
    <button type="button">{submitLabel}</button>
  ),
}));

vi.mock("@/features/auth/passkeys/StepUpPasskeyForm", () => ({
  default: ({ submit_label: submitLabel }: { submit_label: string }) => (
    <button type="button">{submitLabel}</button>
  ),
}));

const { default: OrgEntraSettingsEdit } = await import("@/pages/auth/org/settings/entras/edit");
const { default: OrgEntraSettingsShow } = await import("@/pages/auth/org/settings/entras/show");
const { default: OrgPasskeySettingsEdit } = await import("@/pages/auth/org/settings/passkeys/edit");
const { default: OrgPasskeyRegistrationPage } =
  await import("@/pages/auth/org/settings/passkeys/new");
const { default: OrgMfaPasskeyPage } =
  await import("@/pages/auth/org/sign/in/challenge/passkeys/new");
const { default: OrgPasskeySignInPage } = await import("@/pages/auth/org/sign/in/passkeys/new");
const { default: OrgSecretSignInPage } = await import("@/pages/auth/org/sign/in/secrets/new");
const { default: OrgSignInEntry } = await import("@/pages/auth/org/sign/ins/show");
const { default: OrgInvitationPage } = await import("@/pages/auth/org/sign/up/invitations/new");
const { default: OrgSignUpEntry } = await import("@/pages/auth/org/sign/ups/show");
const { default: OrgEntraSessionEntry } = await import("@/pages/auth/org/social/sessions/new");
const { default: OrgVerificationPasskeyPage } =
  await import("@/pages/auth/org/verification/passkeys/new");
const { default: OrgVerificationSetup } = await import("@/pages/auth/org/verification/setups/new");
const { default: OrgVerificationEntry } = await import("@/pages/auth/org/verifications/show");

const turnstile = {
  site_key: "site-key",
  mode: "render" as const,
  action: null,
  cdata: null,
};

describe("OrgEntraSettingsEdit", () => {
  const props = {
    title: "Entra ID",
    heading: "Entra ID 連携",
    back_link: { label: "戻る", href: "/settings" },
    connected: false,
    connected_notice: null,
    unavailable_notice: null,
    form: { action: "/settings/entra", submit_label: "連携する" },
  };

  it("offers the connect form when the tenant is available and not yet connected", () => {
    const markup = renderToStaticMarkup(<OrgEntraSettingsEdit {...props} />);

    expect(markup).toContain('action="/settings/entra"');
    expect(markup).toContain("連携する");
    expect(markup).not.toContain("Connected");
  });

  it("shows the connected notice and omits the form once connected", () => {
    const markup = renderToStaticMarkup(
      <OrgEntraSettingsEdit
        {...props}
        connected
        connected_notice="user@example.test として連携済みです"
        form={null}
      />,
    );

    expect(markup).toContain("Connected");
    expect(markup).toContain("user@example.test として連携済みです");
    expect(markup).not.toContain("<form");
  });

  it("shows the connected state with no notice when the server sent none", () => {
    const markup = renderToStaticMarkup(
      <OrgEntraSettingsEdit
        {...props}
        connected
        form={null}
      />,
    );

    expect(markup).toContain("Connected");
    expect(markup.match(/<p/gu)).toHaveLength(1);
  });

  it("shows the unavailable notice when the tenant is not configured", () => {
    const markup = renderToStaticMarkup(
      <OrgEntraSettingsEdit
        {...props}
        form={null}
        unavailable_notice="この組織にはEntra IDが設定されていません"
      />,
    );

    expect(markup).toContain("この組織にはEntra IDが設定されていません");
  });
});

describe("OrgEntraSettingsShow", () => {
  it("draws the connection status and a link to change it", () => {
    const markup = renderToStaticMarkup(
      <OrgEntraSettingsShow
        title="Entra ID"
        heading="Entra ID 連携"
        back_link={{ label: "戻る", href: "/settings" }}
        status="user@example.test として連携済みです"
        edit_link={{ label: "連携を解除する", href: "/settings/entra/edit" }}
      />,
    );

    expect(markup).toContain("user@example.test として連携済みです");
    expect(markup).toMatch(/<a href="\/settings\/entra\/edit"[^>]*>連携を解除する<\/a>/u);
  });
});

describe("OrgPasskeySettingsEdit", () => {
  const props = {
    title: "パスキーの名前を変更",
    form_action: "/settings/passkeys/1",
    description_label: "名前",
    description_value: "MacBook",
    submit_label: "保存",
    cancel_link: { label: "キャンセル", href: "/settings/passkeys" },
    errors_title: "エラー",
    errors: [] as string[],
    turnstile,
  };

  it("carries the passkey's current name into the field", () => {
    const markup = renderToStaticMarkup(<OrgPasskeySettingsEdit {...props} />);

    expect(markup).toContain('name="_method" value="patch"');
    expect(markup).toContain("MacBook");
  });

  it("lists the validation errors a rejected rename produced", () => {
    const markup = renderToStaticMarkup(
      <OrgPasskeySettingsEdit
        {...props}
        errors={["名前を入力してください"]}
      />,
    );

    expect(markup).toContain("名前を入力してください");
  });
});

describe("OrgPasskeyRegistrationPage", () => {
  it("hands the ceremony panel its props and links back", () => {
    const markup = renderToStaticMarkup(
      <OrgPasskeyRegistrationPage
        title="パスキー登録"
        description="新しいパスキーを登録します"
        registration={{
          options_url: "/settings/passkeys/options",
          verification_url: "/settings/passkeys/verification",
          turnstile_site_key: "site-key",
          turnstile_error_message: "失敗しました",
          description_label: "名前",
          description_placeholder: "MacBook",
          submit_label: "登録する",
        }}
        cancel_link={{ label: "キャンセル", href: "/settings/passkeys" }}
      />,
    );

    expect(markup).toContain("登録する");
    expect(markup).toMatch(/<a href="\/settings\/passkeys"[^>]*>キャンセル<\/a>/u);
  });
});

describe("OrgMfaPasskeyPage", () => {
  it("hands the step-up form its props", () => {
    const markup = renderToStaticMarkup(
      <OrgMfaPasskeyPage
        title="パスキーで確認"
        description="サインインを完了するにはパスキーで確認してください"
        form={{
          action: "/sign/in/challenge/passkeys",
          param_scope: "mfa_passkey_form",
          challenge_id: "challenge-1",
          request_options: { challenge: "abc" },
          submit_label: "確認する",
        }}
        back_link={{ label: "戻る", href: "/sign/in" }}
      />,
    );

    expect(markup).toContain("確認する");
  });
});

describe("OrgPasskeySignInPage", () => {
  it("hands the authentication panel its props", () => {
    const markup = renderToStaticMarkup(
      <OrgPasskeySignInPage
        title="パスキーでサインイン"
        description="登録済みのパスキーでサインインします"
        panel={{
          options_url: "/sign/in/passkeys/options",
          verification_url: "/sign/in/passkeys/verification",
          region: "jp",
          identifier_param: "operator_id",
          turnstile_site_key: "site-key",
          turnstile_error_message: "失敗しました",
          field: {
            label: "操作者ID",
            placeholder: "operator-id",
            min_length: 1,
            max_length: 255,
            pattern: "",
          },
          submit_label: "サインイン",
        }}
        back_link={{ label: "戻る", href: "/sign/in" }}
      />,
    );

    expect(markup).toContain("サインイン");
  });
});

describe("OrgSecretSignInPage", () => {
  const props = {
    title: "パスワードでサインイン",
    form_action: "/sign/in/secrets",
    hidden_fields: { pt: null as string | null, ri: "jp" },
    errors_title: "エラー",
    errors: [] as string[],
    identifier: {
      name: "operator_id",
      label: "操作者ID",
      placeholder: "operator-id",
      min_length: 1,
      max_length: 255,
      pattern: "",
    },
    secret: { name: "password", label: "パスワード", placeholder: "" },
    submit_label: "サインイン",
    back_link: { label: "戻る", href: "/sign/in" },
    turnstile,
  };

  it("omits the pt field when the server carries none", () => {
    const markup = renderToStaticMarkup(<OrgSecretSignInPage {...props} />);

    expect(markup).not.toContain('name="pt"');
    expect(markup).toContain('name="ri" value="jp"');
  });

  it("carries the pt field when the server carries one", () => {
    const markup = renderToStaticMarkup(
      <OrgSecretSignInPage
        {...props}
        hidden_fields={{ pt: "return-token", ri: "jp" }}
      />,
    );

    expect(markup).toContain('name="pt" value="return-token"');
  });

  it("lists the validation errors a rejected sign-in produced", () => {
    const markup = renderToStaticMarkup(
      <OrgSecretSignInPage
        {...props}
        errors={["資格情報が正しくありません"]}
      />,
    );

    expect(markup).toContain("資格情報が正しくありません");
  });
});

describe("OrgSignInEntry", () => {
  const props = {
    title: "サインイン",
    description: "方法を選んでください",
    methods: [
      { key: "secret", kind: "link" as const, label: "パスワード", href: "/sign/in/secrets/new" },
      {
        key: "entra",
        kind: "provider" as const,
        label: "Microsoft Entra ID",
        href: "/sign/in/entra",
      },
    ],
    registration_link: { label: "招待コードをお持ちですか？", href: "/sign/up" },
    back_to_root: { label: "トップへ", href: "/" },
  };

  it("draws a document link for a link method and a POST form for a provider method", () => {
    const markup = renderToStaticMarkup(<OrgSignInEntry {...props} />);

    expect(markup).toMatch(/<a href="\/sign\/in\/secrets\/new"[\s\S]*?>パスワード</u);
    expect(markup).toContain('action="/sign/in/entra" method="post"');
    expect(markup).toContain('value="Microsoft Entra ID"');
    expect(markup).toMatch(/<a href="\/sign\/up"[^>]*>招待コードをお持ちですか？<\/a>/u);
  });

  it("omits the registration link when the server sent none", () => {
    const markup = renderToStaticMarkup(
      <OrgSignInEntry
        {...props}
        registration_link={null}
      />,
    );

    expect(markup).not.toContain("招待コードをお持ちですか？");
  });
});

describe("OrgInvitationPage", () => {
  const props = {
    title: "招待コードの入力",
    description: "招待コードを入力してください",
    form_error: null as string | null,
    form_action: "/sign/up/invitations",
    invitation_code_label: "招待コード",
    invitation_code: "",
    submit_label: "次へ",
    back_link: { label: "戻る", href: "/sign/up" },
    turnstile,
  };

  it("draws the form with no error list when nothing was rejected", () => {
    const markup = renderToStaticMarkup(<OrgInvitationPage {...props} />);

    expect(markup).not.toContain('role="alert"');
    expect(markup).toContain('name="invitation_code"');
  });

  it("shows the rejected code's error", () => {
    const markup = renderToStaticMarkup(
      <OrgInvitationPage
        {...props}
        form_error="招待コードが正しくありません"
        invitation_code="wrong-code"
      />,
    );

    expect(markup).toContain("招待コードが正しくありません");
    expect(markup).toContain('value="wrong-code"');
  });
});

describe("OrgSignUpEntry", () => {
  const props = {
    title: "登録",
    description: "操作者の登録には招待が必要です" as string | null,
    suspended_notice: null as string | null,
    recruit: { prompt: "招待をご希望ですか？", label: "お問い合わせ", href: "/contact" },
    sign_in_link: { label: "サインインはこちら", href: "/sign/in" },
    back_to_root: { label: "トップへ", href: "/" },
  };

  it("draws the recruitment prompt and the sign-in link", () => {
    const markup = renderToStaticMarkup(<OrgSignUpEntry {...props} />);

    expect(markup).toContain("招待をご希望ですか？");
    expect(markup).toMatch(/<a href="\/contact"[^>]*>お問い合わせ<\/a>/u);
    expect(markup).toMatch(/<a href="\/sign\/in"[^>]*>サインインはこちら<\/a>/u);
  });

  it("shows only the suspension notice while the kill switch is on", () => {
    const markup = renderToStaticMarkup(
      <OrgSignUpEntry
        {...props}
        suspended_notice="現在、登録の受付を停止しています"
      />,
    );

    expect(markup).toContain('data-test-id="sign-up-suspended"');
    expect(markup).toContain("現在、登録の受付を停止しています");
    expect(markup).not.toContain("お問い合わせ");
  });

  it("omits the description and the back link when the server sent none", () => {
    const markup = renderToStaticMarkup(
      <OrgSignUpEntry
        {...props}
        description={null}
        recruit={null}
        sign_in_link={null}
        back_to_root={null}
      />,
    );

    expect(markup).not.toContain("操作者の登録には招待が必要です");
    expect(markup).not.toContain("お問い合わせ");
  });
});

describe("OrgEntraSessionEntry", () => {
  it("offers the Entra continuation form when it is available", () => {
    const markup = renderToStaticMarkup(
      <OrgEntraSessionEntry
        title="Microsoft Entra ID"
        unavailable_notice={null}
        form={{ action: "/sign/in/entra/continue", submit_label: "続ける" }}
      />,
    );

    expect(markup).toContain('action="/sign/in/entra/continue"');
    expect(markup).toContain('class="btn-entra"');
  });

  it("shows the unavailable notice instead of a form when the kill switch is on", () => {
    const markup = renderToStaticMarkup(
      <OrgEntraSessionEntry
        title="Microsoft Entra ID"
        unavailable_notice="現在ご利用いただけません"
        form={null}
      />,
    );

    expect(markup).toContain("現在ご利用いただけません");
    expect(markup).not.toContain("<form");
  });
});

describe("OrgVerificationPasskeyPage", () => {
  it("draws the step-up form with no error sentence when nothing failed", () => {
    const markup = renderToStaticMarkup(
      <OrgVerificationPasskeyPage
        title="パスキーで確認"
        description="本人確認のためパスキーで確認してください"
        errors_sentence={null}
        form={{
          action: "/verification/passkeys",
          param_scope: "verification",
          challenge_id: "challenge-1",
          request_options: { challenge: "abc" },
          submit_label: "確認する",
        }}
        back_link={{ label: "戻る", href: "/verification" }}
      />,
    );

    expect(markup).not.toContain('role="alert"');
    expect(markup).toContain("確認する");
  });

  it("shows the error sentence a failed attempt produced", () => {
    const markup = renderToStaticMarkup(
      <OrgVerificationPasskeyPage
        title="パスキーで確認"
        description="本人確認のためパスキーで確認してください"
        errors_sentence="確認に失敗しました"
        form={{
          action: "/verification/passkeys",
          param_scope: "verification",
          challenge_id: "challenge-1",
          request_options: { challenge: "abc" },
          submit_label: "確認する",
        }}
        back_link={{ label: "戻る", href: "/verification" }}
      />,
    );

    expect(markup).toContain("確認に失敗しました");
  });
});

describe("OrgVerificationSetup", () => {
  it("lists the setup methods and links back", () => {
    const markup = renderToStaticMarkup(
      <OrgVerificationSetup
        title="確認方法の設定"
        description="いずれかの方法を設定してください"
        back_link={{ label: "戻る", href: "/" }}
        methods={[{ key: "passkey", label: "パスキーを設定する", href: "/settings/passkeys/new" }]}
      />,
    );

    expect(markup).toMatch(/<a href="\/settings\/passkeys\/new"[\s\S]*?>パスキーを設定する</u);
  });

  it("draws with no back link when the server sent none", () => {
    const markup = renderToStaticMarkup(
      <OrgVerificationSetup
        title="確認方法の設定"
        description="いずれかの方法を設定してください"
        back_link={null}
        methods={[]}
      />,
    );

    expect(markup).toMatch(/<h1[^>]*>確認方法の設定<\/h1>/u);
  });
});

describe("OrgVerificationEntry", () => {
  const props = {
    title: "本人確認",
    section_title: "確認方法",
    section_description: "いずれかの方法で確認してください",
    notice: null as string | null,
    no_methods: null as string | null,
    methods: [{ key: "passkey", label: "パスキーで確認する", href: "/verification/passkeys/new" }],
  };

  it("lists the available verification methods", () => {
    const markup = renderToStaticMarkup(<OrgVerificationEntry {...props} />);

    expect(markup).toMatch(/<a href="\/verification\/passkeys\/new"[\s\S]*?>パスキーで確認する</u);
  });

  it("shows the notice above the methods when the server sent one", () => {
    const markup = renderToStaticMarkup(
      <OrgVerificationEntry
        {...props}
        notice="セッションの有効期限が近づいています"
      />,
    );

    expect(markup).toContain("セッションの有効期限が近づいています");
  });

  it("shows the no-methods notice instead of a list when none are configured", () => {
    const markup = renderToStaticMarkup(
      <OrgVerificationEntry
        {...props}
        methods={[]}
        no_methods="確認方法が設定されていません"
      />,
    );

    expect(markup).toContain("確認方法が設定されていません");
    expect(markup).not.toContain("<ul");
  });
});
