import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// These forms read their rejected-value message from `useForm`'s own `errors`, not from
// `usePage`; every other spec's mock always answers an empty one, so the error-shown branch never
// ran anywhere else.
vi.mock("@inertiajs/react", () => ({
  useForm: (initial: Record<string, unknown>) => ({
    data: initial,
    setData: vi.fn(),
    errors: {
      pass_code: "コードが正しくありません",
      address: "メールアドレスの形式が正しくありません",
      description: "名前を入力してください",
    },
    processing: false,
    patch: vi.fn(),
    post: vi.fn(),
  }),
}));

vi.mock("@/features/turnstile/TurnstileWidget", () => ({
  default: () => <div />,
}));

const { default: SignInEmailEdit } = await import("@/features/auth/SignInEmailEdit");
const { default: SignInEmailNew } = await import("@/features/auth/SignInEmailNew");
const { default: PasskeyEdit } = await import("@/features/auth/settings/PasskeyEdit");

describe("SignInEmailEdit", () => {
  it("shows the rejected code's own message on the field", () => {
    const markup = renderToStaticMarkup(
      <SignInEmailEdit
        title="コードの入力"
        description="説明"
        action="/sign/in/email"
        pt={null}
        field_label="コード"
        field_placeholder="000000"
        submit_label="確認"
        delivery_help="届かない場合"
        return_link={{ label: "もどる", href: "/sign/in/email/new" }}
        resend={{
          endpoint: "/web/v0/in/email/otp",
          state: "resend-state",
          messages: {
            button_label: "再送信",
            sent_message: "送信しました",
            too_soon_message: "しばらく待ってください",
            failed_message: "失敗しました",
          },
        }}
        turnstile={{ site_key: "site-key", mode: "render", action: null, cdata: null }}
      />,
    );

    expect(markup).toContain("コードが正しくありません");
    expect(markup).toContain("animate-shake");
  });
});

describe("SignInEmailNew", () => {
  it("shows the rejected address's own message on the field", () => {
    const markup = renderToStaticMarkup(
      <SignInEmailNew
        title="メールでログイン"
        description="説明"
        action="/sign/in/email"
        pt={null}
        field_label="メールアドレス"
        submit_label="送信"
        back_link={{ label: "もどる", href: "/sign/in" }}
        turnstile={{ site_key: "site-key", mode: "render", action: null, cdata: null }}
      />,
    );

    expect(markup).toContain("メールアドレスの形式が正しくありません");
    expect(markup).toContain("animate-shake");
  });
});

describe("PasskeyEdit", () => {
  it("shows the rejected description's own message on the field", () => {
    const markup = renderToStaticMarkup(
      <PasskeyEdit
        title="パスキーの編集"
        action="/settings/passkey/pk_1"
        field_label="説明"
        description="MacBook"
        submit_label="保存"
        cancel_link={{ label: "中止", href: "/settings/passkey" }}
        turnstile={{ site_key: "site-key", mode: "execute", action: null, cdata: null }}
      />,
    );

    expect(markup).toContain("名前を入力してください");
  });
});
