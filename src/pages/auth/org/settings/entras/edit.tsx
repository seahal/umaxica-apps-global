// Connecting the operator's Microsoft Entra ID identity.
//
// The connect button is a document POST to the settings endpoint, which redirects into the Entra
// ceremony, so it stays a native form rather than an Inertia visit. Whether a connection may be
// offered at all is a server decision: a connected identity arrives with a notice and no form.
import { csrfToken } from "@/features/auth/csrf";

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
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <a href={backLink.href}>{backLink.label}</a>

      <div>
        <h3>{heading}</h3>

        {connected ? (
          <>
            <p>Connected</p>
            {connectedNotice ? <p>{connectedNotice}</p> : null}
          </>
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
            <input
              type="submit"
              value={submitLabel}
            />
          </form>
        ))}

        {emptyNotice ? <p>{emptyNotice}</p> : null}
      </div>
    </section>
  );
}
