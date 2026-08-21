import { router } from "@inertiajs/react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";
import TextLink from "@/components/ui/TextLink";
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
    <Page
      title={title}
      up={backLink}
      width="wide"
      actions={
        <ButtonLink
          href={newLink.href}
          size="sm"
          inertia
        >
          {newLink.label}
        </ButtonLink>
      }
    >
      <Table>
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
              <td className="whitespace-nowrap text-fg-muted">{secret.created_at}</td>
              <td className="whitespace-nowrap text-fg-muted">{secret.last_used_at}</td>
              <td>
                <div className="flex flex-wrap items-center gap-3">
                  <TextLink
                    href={secret.edit_url}
                    inertia
                  >
                    {editLabel}
                  </TextLink>
                  <Button
                    type="button"
                    variant="danger"
                    size="sm"
                    onPress={() => destroy(secret.destroy_url)}
                  >
                    {destroyLabel}
                  </Button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </Table>
      {dialog}
    </Page>
  );
}
