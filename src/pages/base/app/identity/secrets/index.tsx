import { Link, router } from "@inertiajs/react";

import { useConfirm } from "@/components/ConfirmDialog";
import type { IdentityLink } from "@/types/identity";

type SecretRow = {
  public_id: string;
  name: string;
  created_at: string;
  last_used_at: string;
  edit_url: string;
  destroy_url: string;
};

type Props = {
  title: string;
  back_link: IdentityLink;
  new_link: IdentityLink;
  table_headings: { name: string; created_at: string; last_used_at: string; actions: string };
  edit_label: string;
  destroy_label: string;
  destroy_confirm: string;
  secret_credentials: SecretRow[];
};

export default function SecretsIndex({
  title,
  back_link: backLink,
  new_link: newLink,
  table_headings: headings,
  edit_label: editLabel,
  destroy_label: destroyLabel,
  destroy_confirm: destroyConfirm,
  secret_credentials: secretCredentials,
}: Props) {
  const { confirm, dialog } = useConfirm();

  const destroy = (url: string) => {
    confirm({ message: destroyConfirm, confirmLabel: destroyLabel }, () => router.delete(url));
  };

  return (
    <section>
      <a href={backLink.href}>{backLink.label}</a>

      <h1>{title}</h1>

      <Link href={newLink.href}>{newLink.label}</Link>

      <table>
        <thead>
          <tr>
            <th scope="col">{headings.name}</th>
            <th scope="col">{headings.created_at}</th>
            <th scope="col">{headings.last_used_at}</th>
            <th scope="col">{headings.actions}</th>
          </tr>
        </thead>
        <tbody>
          {secretCredentials.map((secret) => (
            <tr key={secret.public_id}>
              <td>{secret.name}</td>
              <td>{secret.created_at}</td>
              <td>{secret.last_used_at}</td>
              <td>
                <Link href={secret.edit_url}>{editLabel}</Link>
                <button
                  type="button"
                  onClick={() => destroy(secret.destroy_url)}
                >
                  {destroyLabel}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {dialog}
    </section>
  );
}
