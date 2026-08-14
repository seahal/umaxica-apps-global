// The passkeys registered on an app account.
//
// Each row is serialized by the server: a public id, the description its owner gave it, formatted
// timestamps and the URLs of the actions this actor may take. Deleting one carries an invisible
// Turnstile token, which only the server decides the worth of.
import { router } from "@inertiajs/react";
import { useState } from "react";

import type { SettingsLink, SettingsTurnstile } from "@/features/auth/settings/links";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

type PasskeyRow = {
  public_id: string;
  description: string | null;
  created_at: string;
  last_used_at: string;
  edit_href: string;
  destroy_href: string;
};

type Props = {
  title: string;
  back_link: SettingsLink;
  new_link: SettingsLink;
  columns: {
    description: string;
    created_at: string;
    last_used_at: string;
    actions: string;
  };
  empty_message: string;
  edit_label: string;
  destroy_label: string;
  destroy_confirm: string;
  turnstile: SettingsTurnstile;
  passkeys: PasskeyRow[];
};

export default function PasskeysIndex({
  back_link: backLink,
  new_link: newLink,
  columns,
  empty_message: emptyMessage,
  edit_label: editLabel,
  destroy_label: destroyLabel,
  destroy_confirm: destroyConfirm,
  turnstile,
  passkeys,
}: Props) {
  const [token, setToken] = useState("");

  const destroy = (href: string) => {
    if (!window.confirm(destroyConfirm)) {
      return;
    }

    router.delete(href, { data: { "cf-turnstile-response": token } });
  };

  return (
    <section className="mx-auto flex w-full max-w-3xl flex-col gap-6 p-6">
      <a href={backLink.href}>{backLink.label}</a>

      <div>
        <a href={newLink.href}>{newLink.label}</a>
      </div>

      <TurnstileWidget
        site_key={turnstile.site_key}
        mode={turnstile.mode}
        action={turnstile.action}
        cdata={turnstile.cdata}
        onToken={setToken}
      />

      <table>
        <thead>
          <tr>
            <th scope="col">{columns.description}</th>
            <th scope="col">{columns.created_at}</th>
            <th scope="col">{columns.last_used_at}</th>
            <th scope="col">
              <span>{columns.actions}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          {passkeys.map((passkey) => (
            <tr key={passkey.public_id}>
              <td>{passkey.description}</td>
              <td>{passkey.created_at}</td>
              <td>{passkey.last_used_at}</td>
              <td>
                <a href={passkey.edit_href}>{editLabel}</a>
                <button
                  type="button"
                  onClick={() => destroy(passkey.destroy_href)}
                >
                  {destroyLabel}
                </button>
              </td>
            </tr>
          ))}
          {passkeys.length === 0 ? (
            <tr>
              <td
                colSpan={4}
                className="italic"
              >
                {emptyMessage}
              </td>
            </tr>
          ) : null}
        </tbody>
      </table>
    </section>
  );
}
