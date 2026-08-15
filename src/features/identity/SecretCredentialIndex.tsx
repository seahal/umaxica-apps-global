// The secret credential inventory.
//
// The raw secret is never a prop: it exists only on the creation screen, in the field the operator
// types, and the server holds the digest.
import { Link } from "@inertiajs/react";

import { useConfirm } from "@/components/ConfirmDialog";
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

function DestroyForm({
  href,
  label,
  message,
  turnstile,
}: {
  href: string;
  label: string;
  message: string;
  turnstile: TurnstileProps;
}) {
  const { confirm, dialog } = useConfirm();

  // The submission is held back until the actor accepts, then replayed with `submit()`, which
  // sends the same document DELETE without running this handler again.
  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    confirm({ message, confirmLabel: label }, () => form.submit());
  };

  return (
    <>
      <form
        action={href}
        method="post"
        data-turbo="false"
        onSubmit={submit}
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
          value={label}
        />
      </form>
      {dialog}
    </>
  );
}

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
                <DestroyForm
                  href={credential.destroy_href}
                  label={destroyLabel}
                  message={destroyConfirm}
                  turnstile={turnstile}
                />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
