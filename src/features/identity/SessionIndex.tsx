// The session inventory of an identity surface.
//
// Which sessions may be revoked is a server decision: the current session arrives without a
// `revoke` action, and the bulk revocations are absent when there is no other session to revoke.
import { Link } from "@inertiajs/react";

import { csrfToken } from "@/lib/csrf";

export type SessionAction = {
  label: string;
  href: string;
  confirm: string;
};

export type SessionRow = {
  public_id: string;
  current: boolean;
  current_label: string | null;
  status: string;
  kind: string;
  binding: string;
  last_activity: string;
  created: string;
  refresh_expires: string;
  revoke: SessionAction | null;
};

export type SessionIndexProps = {
  title: string;
  back_link: { label: string; href: string };
  empty_message: string;
  columns: {
    session: string;
    kind: string;
    binding: string;
    last_activity: string;
    created: string;
    refresh_expires: string;
  };
  bulk_revocations: { others: SessionAction; all: SessionAction } | null;
  sessions: SessionRow[];
};

// Revocation stays a DELETE submitted as a document, exactly as `button_to` did: it ends session
// state the current page depends on, so the server's redirect drives the next screen.
function RevokeButton({ action }: { action: SessionAction }) {
  return (
    <form
      action={action.href}
      method="post"
      data-turbo="false"
      onSubmit={(event) => {
        if (!window.confirm(action.confirm)) {
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
      <input
        type="submit"
        value={action.label}
      />
    </form>
  );
}

export default function SessionIndex({
  title,
  back_link: backLink,
  empty_message: emptyMessage,
  columns,
  bulk_revocations: bulkRevocations,
  sessions,
}: SessionIndexProps) {
  return (
    <section>
      <h1>{title}</h1>
      <Link href={backLink.href}>{backLink.label}</Link>

      {bulkRevocations ? (
        <div>
          <RevokeButton action={bulkRevocations.others} />
          <RevokeButton action={bulkRevocations.all} />
        </div>
      ) : null}

      {sessions.length > 0 ? (
        <div>
          <table>
            <thead>
              <tr>
                <th>{columns.session}</th>
                <th>{columns.kind}</th>
                <th>{columns.binding}</th>
                <th>{columns.last_activity}</th>
                <th>{columns.created}</th>
                <th>{columns.refresh_expires}</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {sessions.map((session) => (
                <tr
                  key={session.public_id}
                  className={session.current ? "bg-slate-50 font-semibold" : undefined}
                >
                  <td>
                    <div>
                      <span>{session.public_id}</span>
                      {session.current_label ? <span>{session.current_label}</span> : null}
                    </div>
                    <p>{session.status}</p>
                  </td>
                  <td>{session.kind}</td>
                  <td>{session.binding}</td>
                  <td>{session.last_activity}</td>
                  <td>{session.created}</td>
                  <td>{session.refresh_expires}</td>
                  <td>{session.revoke ? <RevokeButton action={session.revoke} /> : null}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <p>{emptyMessage}</p>
      )}
    </section>
  );
}
