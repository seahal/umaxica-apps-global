// The secret credential inventory.
//
// The raw secret is never a prop: it exists only on the creation screen, in the field the operator
// types, and the server holds the digest.
import { Link } from "@inertiajs/react";

import type { LabelledLink, TurnstileProps } from "@/features/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

export type SecretCredentialRow = {
  public_id: string;
  name: string;
  created_at: string;
  last_used_at: string;
  edit_href: string;
  destroy_href: string;
};

export type SecretCredentialIndexProps = {
  title: string;
  description: string;
  new_link: LabelledLink;
  columns: { name: string; created_at: string; last_used_at: string; actions: string };
  edit_label: string;
  destroy_label: string;
  destroy_confirm: string;
  turnstile: TurnstileProps;
  secret_credentials: SecretCredentialRow[];
};

export default function SecretCredentialIndex({
  title,
  description,
  new_link: newLink,
  columns,
  edit_label: editLabel,
  destroy_label: destroyLabel,
  destroy_confirm: destroyConfirm,
  turnstile,
  secret_credentials: secretCredentials,
}: SecretCredentialIndexProps) {
  return (
    <section>
      <h1>{title}</h1>
      <p>{description}</p>

      <div>
        <Link href={newLink.href}>{newLink.label}</Link>
      </div>

      <table>
        <thead>
          <tr>
            <th scope="col">{columns.name}</th>
            <th scope="col">{columns.created_at}</th>
            <th scope="col">{columns.last_used_at}</th>
            <th scope="col">
              <span>{columns.actions}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          {secretCredentials.map((credential) => (
            <tr key={credential.public_id}>
              <td>{credential.name}</td>
              <td>{credential.created_at}</td>
              <td>{credential.last_used_at}</td>
              <td>
                <Link href={credential.edit_href}>{editLabel}</Link>
                <form
                  action={credential.destroy_href}
                  method="post"
                  data-turbo="false"
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
                  />
                  <input
                    type="hidden"
                    name="authenticity_token"
                    value={csrfToken()}
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
        </tbody>
      </table>
    </section>
  );
}
