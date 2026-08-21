// Connecting the operator's Microsoft Entra ID identity.
//
// The connect button is a document POST to the settings endpoint, which redirects into the Entra
// ceremony, so it stays a native form rather than an Inertia visit. Whether a connection may be
// offered at all is a server decision: a connected identity arrives with a notice and no form.
import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
import { csrfToken } from "@/lib/csrf";

export type OrgEntraSettingsEditProps = {
  title: string;
  heading: string;
  back_link: { label: string; href: string };
  connected: boolean;
  connected_notice: string | null;
  empty_notice: string | null;
  form_action: string;
  submit_label: string;
  connections: { public_id: string }[];
};

export default function OrgEntraSettingsEdit({
  heading,
  back_link: backLink,
  connected,
  connected_notice: connectedNotice,
  empty_notice: emptyNotice,
  form_action: formAction,
  submit_label: submitLabel,
  connections,
}: OrgEntraSettingsEditProps) {
  return (
    <Page
      title={heading}
      up={backLink}
      width="narrow"
    >
      <Card>
        {connected ? (
          <div className="flex flex-col gap-1 text-sm">
            <p className="font-medium text-fg">Connected</p>
            {connectedNotice ? <p className="text-fg-muted">{connectedNotice}</p> : null}
          </div>
        ) : null}

        {connections.map((connection) => (
          <form
            key={connection.public_id}
            action={formAction}
            method="post"
          >
            <input
              type="hidden"
              name="authenticity_token"
              value={csrfToken()}
              readOnly
            />
            <input
              type="hidden"
              name="entra[connection_public_id]"
              value={connection.public_id}
              readOnly
            />
            <Button type="submit">{submitLabel}</Button>
          </form>
        ))}

        {emptyNotice ? <p className="text-sm text-fg-muted">{emptyNotice}</p> : null}
      </Card>
    </Page>
  );
}
