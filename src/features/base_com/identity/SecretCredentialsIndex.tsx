import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import type { PageLink, TurnstileProps } from "@/features/base_com/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

// Replaces `app/views/base/com/identity/secret_credentials/index.html.erb`.

export type SecretCredentialRow = {
  public_id: string;
  name: string;
  created_at: string;
  last_used_at: string;
  show_link: PageLink;
  edit_link: PageLink;
  destroy_url: string;
};

export type SecretCredentialsIndexProps = {
  title: string;
  back_link: PageLink;
  new_link: PageLink;
  columns: { name: string; created: string; last_used: string; actions: string };
  destroy_confirm: string;
  destroy_label: string;
  turnstile: TurnstileProps;
  credentials: SecretCredentialRow[];
};

function DestroyForm({
  url,
  confirm,
  label,
  turnstile,
}: {
  url: string;
  confirm: string;
  label: string;
  turnstile: TurnstileProps;
}) {
  const [token, setToken] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!window.confirm(confirm)) {
      return;
    }
    router.delete(url, {
      data: { "cf-turnstile-response": token },
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
    });
  };

  return (
    <form onSubmit={submit}>
      <TurnstileWidget
        {...turnstile}
        onToken={setToken}
      />
      <button
        type="submit"
        disabled={processing}
      >
        {label}
      </button>
    </form>
  );
}

export default function SecretCredentialsIndex({
  title,
  back_link: backLink,
  new_link: newLink,
  columns,
  destroy_confirm: destroyConfirm,
  destroy_label: destroyLabel,
  turnstile,
  credentials,
}: SecretCredentialsIndexProps) {
  return (
    <section>
      <h1>{title}</h1>
      <Link href={backLink.href}>{backLink.label}</Link>

      <div>
        <Link href={newLink.href}>{newLink.label}</Link>
      </div>

      <table>
        <thead>
          <tr>
            <th scope="col">{columns.name}</th>
            <th scope="col">{columns.created}</th>
            <th scope="col">{columns.last_used}</th>
            <th scope="col">{columns.actions}</th>
          </tr>
        </thead>
        <tbody>
          {credentials.map((credential) => (
            <tr key={credential.public_id}>
              <td>{credential.name}</td>
              <td>{credential.created_at}</td>
              <td>{credential.last_used_at}</td>
              <td>
                <Link href={credential.show_link.href}>{credential.show_link.label}</Link>
                <Link href={credential.edit_link.href}>{credential.edit_link.label}</Link>
                <DestroyForm
                  url={credential.destroy_url}
                  confirm={destroyConfirm}
                  label={destroyLabel}
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
