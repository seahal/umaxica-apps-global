import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";
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

const LINK = "text-sm text-fg-muted underline-offset-4 hover:text-fg hover:underline";
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
  const { confirm: requestConfirmation, dialog } = useConfirm();

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    requestConfirmation({ message: confirm, confirmLabel: label }, () => {
      router.delete(url, {
        data: { "cf-turnstile-response": token },
        onStart: () => setProcessing(true),
        onFinish: () => setProcessing(false),
      });
    });
  };

  return (
    <>
      <form
        onSubmit={submit}
        className="inline-flex"
      >
        <TurnstileWidget
          {...turnstile}
          onToken={setToken}
        />
        <Button
          type="submit"
          variant="danger"
          size="sm"
          isDisabled={processing}
        >
          {label}
        </Button>
      </form>
      {dialog}
    </>
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
    <Page
      title={title}
      up={backLink}
      upVisit="inertia"
    >
      <div>
        <ButtonLink
          href={newLink.href}
          inertia
        >
          {newLink.label}
        </ButtonLink>
      </div>

      <Table>
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
            <tr
              key={credential.public_id}
              className="last:border-0"
            >
              <td>{credential.name}</td>
              <td>{credential.created_at}</td>
              <td>{credential.last_used_at}</td>
              <td>
                <div className="flex flex-wrap items-center gap-3">
                  <Link
                    href={credential.show_link.href}
                    className={LINK}
                  >
                    {credential.show_link.label}
                  </Link>
                  <Link
                    href={credential.edit_link.href}
                    className={LINK}
                  >
                    {credential.edit_link.label}
                  </Link>
                  <DestroyForm
                    url={credential.destroy_url}
                    confirm={destroyConfirm}
                    label={destroyLabel}
                    turnstile={turnstile}
                  />
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </Table>
    </Page>
  );
}
