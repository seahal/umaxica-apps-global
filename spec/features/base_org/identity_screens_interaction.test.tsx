import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// Unlike identity_screens.test.tsx (static markup only), these tests mount the components and fire
// real submit events, which is the only way to reach the confirmation guards on the destructive
// forms.
vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
}));

vi.mock("@/lib/turnstile", () => ({
  waitForTurnstileApi: () =>
    Promise.resolve({ render: () => "widget", execute: () => undefined, remove: () => undefined }),
}));

const { default: TelephoneEdit } = await import("@/features/identity/TelephoneEdit");
const { default: SessionIndex } = await import("@/features/identity/SessionIndex");
const { default: SecretCredentialIndex } =
  await import("@/features/identity/SecretCredentialIndex");
const { default: EmailPreferenceEdit } = await import("@/features/identity/EmailPreferenceEdit");

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

// jsdom has no navigation, so the submit is observed rather than performed.
const submitFirstForm = () => {
  const form = container.querySelector("form");
  const event = new Event("submit", { bubbles: true, cancelable: true });
  act(() => {
    form?.dispatchEvent(event);
  });

  return event;
};

beforeEach(() => {
  vi.spyOn(window, "confirm");
});

afterEach(() => {
  act(() => {
    root.unmount();
  });
  container.remove();
  vi.restoreAllMocks();
});

const turnstile = { site_key: "site", mode: "execute" as const, action: null, cdata: null };

describe("destructive identity forms", () => {
  it("submits the telephone deletion only when the operator confirms", () => {
    const props = {
      title: "Telephone settings",
      number: "+819012345678",
      delete: { label: "Delete", href: "/identity/telephones/1", confirm: "Delete?" },
      cancel_link: { label: "Cancel", href: "/identity/telephones" },
    };

    vi.mocked(window.confirm).mockReturnValue(false);
    mount(<TelephoneEdit {...props} />);

    expect(submitFirstForm().defaultPrevented).toBe(true);

    act(() => {
      root.unmount();
    });
    container.remove();

    vi.mocked(window.confirm).mockReturnValue(true);
    mount(<TelephoneEdit {...props} />);

    expect(submitFirstForm().defaultPrevented).toBe(false);
  });

  it("guards a session revocation", () => {
    vi.mocked(window.confirm).mockReturnValue(false);
    mount(
      <SessionIndex
        title="Sessions"
        back_link={{ label: "Back", href: "/identity" }}
        empty_message="No active sessions were found."
        columns={{
          session: "Session",
          kind: "Kind",
          binding: "Binding",
          last_activity: "Last activity",
          created: "Created",
          refresh_expires: "Refresh expires",
        }}
        bulk_revocations={{
          others: { label: "Revoke others", href: "/identity/other_sessions", confirm: "Sure?" },
          all: { label: "Revoke all", href: "/identity/sessions", confirm: "Sure?" },
        }}
        sessions={[]}
      />,
    );

    expect(submitFirstForm().defaultPrevented).toBe(true);
    expect(window.confirm).toHaveBeenCalledWith("Sure?");
  });

  it("guards a secret credential deletion", () => {
    vi.mocked(window.confirm).mockReturnValue(false);
    mount(
      <SecretCredentialIndex
        title="Secrets"
        description="Manage secrets."
        new_link={{ label: "New", href: "/identity/secrets/new" }}
        columns={{
          name: "Name",
          created_at: "Created",
          last_used_at: "Last used",
          actions: "Actions",
        }}
        edit_label="Edit"
        destroy_label="Delete"
        destroy_confirm="Sure?"
        turnstile={turnstile}
        secret_credentials={[
          {
            public_id: "sec_1",
            name: "abcd",
            created_at: "01/01",
            last_used_at: "-",
            edit_href: "/identity/secrets/sec_1/edit",
            destroy_href: "/identity/secrets/sec_1",
          },
        ]}
      />,
    );

    expect(submitFirstForm().defaultPrevented).toBe(true);
  });

  it("guards an email address deletion without blocking the preference update", () => {
    vi.mocked(window.confirm).mockReturnValue(false);
    mount(
      <EmailPreferenceEdit
        title="Email settings"
        address="staff@example.test"
        form={{
          action: "/identity/emails/eml_1",
          scope: "staff_email",
          promotional: false,
          notifiable: true,
          always_on_label: "Important",
          always_on_description: "Always sent.",
          promotional_label: "Promotional",
          promotional_description: "Campaigns.",
          notifiable_label: "Notifications",
          notifiable_description: "Updates.",
          submit: "Save",
          turnstile,
        }}
        delete={{ label: "Delete", href: "/identity/emails/eml_1", confirm: "Delete?" }}
        cancel_link={{ label: "Cancel", href: "/identity/emails" }}
        error_messages={[]}
      />,
    );

    // The first form is the preference update, which carries no confirmation.
    expect(submitFirstForm().defaultPrevented).toBe(false);

    const deleteForm = container.querySelectorAll("form")[1];
    const event = new Event("submit", { bubbles: true, cancelable: true });
    act(() => {
      deleteForm?.dispatchEvent(event);
    });

    expect(event.defaultPrevented).toBe(true);
  });
});
