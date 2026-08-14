import { router } from "@inertiajs/react";

import type { IdentityLink } from "@/types/identity";

type SessionRow = {
  public_id: string;
  status: string;
  kind: string;
  binding: string;
  last_activity: string;
  created: string;
  refresh_expires: string;
  current: boolean;
  revoke_url: string;
};

type BulkRevocation = {
  others_label: string;
  others_confirm: string;
  others_url: string;
  all_label: string;
  all_confirm: string;
  all_url: string;
};

type Props = {
  title: string;
  empty_message: string;
  back_link: IdentityLink;
  table_headings: {
    session: string;
    kind: string;
    binding: string;
    last_activity: string;
    created: string;
    refresh_expires: string;
  };
  current_label: string;
  revoke_label: string;
  revoke_confirm: string;
  bulk_revocation: BulkRevocation | null;
  sessions: SessionRow[];
};

export default function SessionsIndex({
  title,
  empty_message: emptyMessage,
  back_link: backLink,
  table_headings: headings,
  current_label: currentLabel,
  revoke_label: revokeLabel,
  revoke_confirm: revokeConfirm,
  bulk_revocation: bulkRevocation,
  sessions,
}: Props) {
  const revoke = (url: string, confirmation: string) => {
    if (!window.confirm(confirmation)) {
      return;
    }
    router.delete(url);
  };

  return (
    <section>
      <a href={backLink.href}>{backLink.label}</a>

      <h1>{title}</h1>

      {bulkRevocation ? (
        <div>
          <button
            type="button"
            onClick={() => revoke(bulkRevocation.others_url, bulkRevocation.others_confirm)}
          >
            {bulkRevocation.others_label}
          </button>
          <button
            type="button"
            onClick={() => revoke(bulkRevocation.all_url, bulkRevocation.all_confirm)}
          >
            {bulkRevocation.all_label}
          </button>
        </div>
      ) : null}

      {sessions.length === 0 ? (
        <p>{emptyMessage}</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>{headings.session}</th>
              <th>{headings.kind}</th>
              <th>{headings.binding}</th>
              <th>{headings.last_activity}</th>
              <th>{headings.created}</th>
              <th>{headings.refresh_expires}</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {sessions.map((session) => (
              <tr key={session.public_id}>
                <td>
                  <span>{session.public_id}</span>
                  {session.current ? <span>{currentLabel}</span> : null}
                  <p>{session.status}</p>
                </td>
                <td>{session.kind}</td>
                <td>{session.binding}</td>
                <td>{session.last_activity}</td>
                <td>{session.created}</td>
                <td>{session.refresh_expires}</td>
                <td>
                  {session.current ? null : (
                    <button
                      type="button"
                      onClick={() => revoke(session.revoke_url, revokeConfirm)}
                    >
                      {revokeLabel}
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}
