// The operator's registered passkeys.
//
// Deletion stays a document DELETE form: it carries a stealth Turnstile token in the same
// `cf-turnstile-response` field the server already verifies, so the request shape is unchanged.
import { csrfToken } from "@/features/auth/csrf";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

type PasskeyRow = {
  description: string;
  created_at: string;
  edit_href: string;
  destroy_action: string;
};

type TurnstileConfiguration = {
  site_key: string;
  mode: "render" | "execute";
  action: string | null;
  cdata: string | null;
};

export type OrgPasskeySettingsIndexProps = {
  title: string;
  description: string;
  add_link: { label: string; href: string };
  back_link: { label: string; href: string };
  columns: { description: string; created_at: string; actions: string };
  empty: string;
  edit_label: string;
  destroy_label: string;
  destroy_confirm: string;
  turnstile: TurnstileConfiguration;
  passkeys: PasskeyRow[];
};

export default function OrgPasskeySettingsIndex({
  title,
  description,
  add_link: addLink,
  back_link: backLink,
  columns,
  empty,
  edit_label: editLabel,
  destroy_label: destroyLabel,
  destroy_confirm: destroyConfirm,
  turnstile,
  passkeys,
}: OrgPasskeySettingsIndexProps) {
  return (
    <section className="mx-auto flex w-full max-w-3xl flex-col gap-6 p-6">
      <div>
        <h1>{title}</h1>
        <p>{description}</p>
        <a href={addLink.href}>{addLink.label}</a>
      </div>

      <table>
        <thead>
          <tr>
            <th scope="col">{columns.description}</th>
            <th scope="col">{columns.created_at}</th>
            <th scope="col">
              <span>{columns.actions}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          {passkeys.map((passkey) => (
            <tr key={passkey.destroy_action}>
              <td>{passkey.description}</td>
              <td>{passkey.created_at}</td>
              <td>
                <a href={passkey.edit_href}>{editLabel}</a>
                <form
                  action={passkey.destroy_action}
                  method="post"
                  onSubmit={(event) => {
                    if (!window.confirm(destroyConfirm)) {
                      event.preventDefault();
                    }
                  }}
                >
                  <input
                    type="hidden"
                    name="_method"
                    value="delete"
                    readOnly
                  />
                  <input
                    type="hidden"
                    name="authenticity_token"
                    value={csrfToken()}
                    readOnly
                  />
                  <TurnstileWidget
                    site_key={turnstile.site_key}
                    mode={turnstile.mode}
                    action={turnstile.action}
                    cdata={turnstile.cdata}
                  />
                  <input
                    type="submit"
                    value={destroyLabel}
                  />
                </form>
              </td>
            </tr>
          ))}
          {passkeys.length === 0 ? (
            <tr>
              <td
                colSpan={3}
                className="italic"
              >
                {empty}
              </td>
            </tr>
          ) : null}
        </tbody>
      </table>

      <div>
        <a href={backLink.href}>{backLink.label}</a>
      </div>
    </section>
  );
}
