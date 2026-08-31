// The operator-facing auth screens, rendered with the shapes the server actually sends.
//
// Each one is a decision the server already made -- a suspended sign-up, an unavailable provider, a
// step-up with no configured method -- so the page is asserted in both the present and the absent
// shape of every prop the server may omit. A page that quietly rendered a form the server withheld
// would offer a ceremony the request phase refuses.
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import type { TurnstileApi } from "@/lib/turnstile";
import OrgEntraSettingsEdit from "@/pages/auth/org/settings/entras/edit";
import OrgEntraSettingsShow from "@/pages/auth/org/settings/entras/show";
import OrgSignInEntry from "@/pages/auth/org/sign/ins/show";
import OrgSignUpEntry from "@/pages/auth/org/sign/ups/show";
import OrgEntraSessionEntry from "@/pages/auth/org/social/sessions/new";
import OrgVerificationSetup from "@/pages/auth/org/verification/setups/new";
import OrgVerificationEntry from "@/pages/auth/org/verifications/show";

import { mount } from "../../../support/react";

const BACK = { label: "戻る", href: "/org" };

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="csrf-value">';
  const api: TurnstileApi = { render: vi.fn(() => "widget-1"), execute: vi.fn(), remove: vi.fn() };
  window.turnstile = api;
});

afterEach(() => {
  document.head.innerHTML = "";
  delete window.turnstile;
});

describe("OrgSignUpEntry", () => {
  const props = {
    title: "運営メンバー登録",
    description: "登録は招待制です",
    suspended_notice: null,
    recruit: { prompt: "興味がありますか", label: "採用情報", href: "/careers" },
    sign_in_link: { label: "ログイン", href: "/org/sign/in" },
    back_to_root: BACK,
  };

  it("shows the suspension notice alone when sign-up is switched off", () => {
    const screen = mount(
      <OrgSignUpEntry
        {...props}
        suspended_notice="現在受け付けていません"
      />,
    );

    expect(screen.text("[data-test-id='sign-up-suspended']")).toBe("現在受け付けていません");
    expect(screen.container.querySelectorAll("a")).toHaveLength(0);
  });

  it("offers the recruiting route and the sign-in link", () => {
    const screen = mount(<OrgSignUpEntry {...props} />);
    const links = [...screen.container.querySelectorAll("a")].map((link) => link.textContent);

    expect(screen.text("h1")).toBe("運営メンバー登録");
    expect(links).toContain("採用情報");
    expect(links).toContain("ログイン");
  });

  it("renders without the optional description, links or recruiting block", () => {
    const screen = mount(
      <OrgSignUpEntry
        {...props}
        description={null}
        recruit={null}
        sign_in_link={null}
        back_to_root={null}
      />,
    );

    expect(screen.text("h1")).toBe("運営メンバー登録");
    expect(screen.container.querySelectorAll("a")).toHaveLength(0);
  });
});

describe("OrgSignInEntry", () => {
  const props = {
    title: "ログイン",
    description: "運営メンバー向け",
    methods: [
      { key: "entra", kind: "provider" as const, label: "Entra ID でログイン", href: "/org/entra" },
      { key: "secret", kind: "link" as const, label: "パスワードでログイン", href: "/org/secret" },
    ],
    registration_link: { label: "招待コードをお持ちの方", href: "/org/invitation" },
    back_to_root: BACK,
  };

  it("posts the provider method as a document form and links the rest", () => {
    const screen = mount(<OrgSignInEntry {...props} />);
    const form = screen.container.querySelector("form.social-provider-form");

    expect(form?.getAttribute("action")).toBe("/org/entra");
    expect(form?.getAttribute("method")).toBe("post");
    expect(
      screen.container.querySelector<HTMLInputElement>('input[name="authenticity_token"]')?.value,
    ).toBe("csrf-value");
    expect(
      screen.container.querySelector<HTMLInputElement>(".social-provider-button--entra")?.value,
    ).toBe("Entra ID でログイン");
    expect(screen.container.querySelector('a[href="/org/secret"]')?.textContent).toContain(
      "パスワードでログイン",
    );
  });

  it("omits the registration link when the server sends none", () => {
    const screen = mount(
      <OrgSignInEntry
        {...props}
        registration_link={null}
      />,
    );

    expect(screen.container.querySelector('a[href="/org/invitation"]')).toBeNull();
  });
});

describe("OrgEntraSessionEntry", () => {
  it("offers the ceremony as a document POST", () => {
    const screen = mount(
      <OrgEntraSessionEntry
        title="Entra ID でログイン"
        unavailable_notice={null}
        form={{ action: "/org/entra/session", submit_label: "続ける" }}
      />,
    );

    expect(screen.container.querySelector("form")?.getAttribute("action")).toBe(
      "/org/entra/session",
    );
    expect(screen.container.querySelector<HTMLInputElement>(".btn-entra")?.value).toBe("続ける");
  });

  it("shows the notice and no form when the provider is switched off", () => {
    const screen = mount(
      <OrgEntraSessionEntry
        title="Entra ID でログイン"
        unavailable_notice="現在利用できません"
        form={null}
      />,
    );

    expect(screen.container.textContent).toContain("現在利用できません");
    expect(screen.container.querySelector("form")).toBeNull();
  });
});

describe("OrgEntraSettingsEdit", () => {
  const props = {
    title: "Entra ID",
    heading: "Entra ID 連携",
    back_link: BACK,
    connected: false,
    connected_notice: null,
    unavailable_notice: null,
    form: { action: "/org/settings/entra", submit_label: "連携する" },
  };

  it("offers the connect form when the server allows connecting", () => {
    const screen = mount(<OrgEntraSettingsEdit {...props} />);

    expect(screen.container.querySelector("form")?.getAttribute("action")).toBe(
      "/org/settings/entra",
    );
    expect(screen.text("button")).toBe("連携する");
    expect(screen.container.textContent).not.toContain("Connected");
  });

  it("reports an existing connection with the server's own notice and no form", () => {
    const screen = mount(
      <OrgEntraSettingsEdit
        {...props}
        connected
        connected_notice="2026年8月に連携しました"
        form={null}
      />,
    );

    expect(screen.container.textContent).toContain("Connected");
    expect(screen.container.textContent).toContain("2026年8月に連携しました");
    expect(screen.container.querySelector("form")).toBeNull();
  });

  it("reports a connection without a notice, and an unavailable provider", () => {
    const screen = mount(
      <OrgEntraSettingsEdit
        {...props}
        connected
        form={null}
        unavailable_notice="この環境では利用できません"
      />,
    );

    expect(screen.container.textContent).toContain("Connected");
    expect(screen.container.textContent).toContain("この環境では利用できません");
  });
});

describe("OrgEntraSettingsShow", () => {
  it("shows the connection state and the route to change it", () => {
    const screen = mount(
      <OrgEntraSettingsShow
        title="Entra ID"
        heading="Entra ID 連携"
        back_link={BACK}
        status="未連携"
        edit_link={{ label: "連携を編集", href: "/org/settings/entra/edit" }}
      />,
    );

    expect(screen.container.textContent).toContain("未連携");
    expect(screen.container.querySelector('a[href="/org/settings/entra/edit"]')?.textContent).toBe(
      "連携を編集",
    );
  });
});

describe("OrgVerificationEntry", () => {
  const props = {
    title: "本人確認",
    section_title: "確認方法",
    section_description: "いずれかを選んでください",
    notice: null,
    no_methods: null,
    methods: [{ key: "passkey", label: "パスキー", href: "/org/verification/passkey" }],
  };

  it("lists every method the server offered", () => {
    const screen = mount(<OrgVerificationEntry {...props} />);

    expect(screen.container.querySelectorAll("li")).toHaveLength(1);
    expect(
      screen.container.querySelector('a[href="/org/verification/passkey"]')?.textContent,
    ).toContain("パスキー");
  });

  it("shows the notice and the empty-state text when no method is available", () => {
    const screen = mount(
      <OrgVerificationEntry
        {...props}
        notice="再度確認が必要です"
        no_methods="利用できる方法がありません"
        methods={[]}
      />,
    );

    expect(screen.container.textContent).toContain("再度確認が必要です");
    expect(screen.container.textContent).toContain("利用できる方法がありません");
    expect(screen.container.querySelectorAll("li")).toHaveLength(0);
  });
});

describe("OrgVerificationSetup", () => {
  it("lists the methods an operator may still configure", () => {
    const screen = mount(
      <OrgVerificationSetup
        title="確認方法の設定"
        description="まず方法を登録してください"
        back_link={BACK}
        methods={[{ key: "passkey", label: "パスキーを登録", href: "/org/settings/passkeys/new" }]}
      />,
    );

    expect(
      screen.container.querySelector('a[href="/org/settings/passkeys/new"]')?.textContent,
    ).toContain("パスキーを登録");
  });

  it("renders without an up link when the server sends none", () => {
    const screen = mount(
      <OrgVerificationSetup
        title="確認方法の設定"
        description="まず方法を登録してください"
        back_link={null}
        methods={[]}
      />,
    );

    expect(screen.text("h1")).toBe("確認方法の設定");
  });
});
