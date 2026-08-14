import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import type { ConfirmedAction, PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/sessions/index.html.erb`. Which revocations are offered is
// a server decision: an action the actor may not take is absent from the props rather than hidden.

export type SessionRow = {
  public_id: string;
  current: boolean;
  status: string;
  kind: string;
  binding: string;
  last_activity: string;
  created: string;
  refresh_expires: string;
  revoke: ConfirmedAction | null;
};

export type SessionsIndexProps = {
  title: string;
  back_link: PageLink;
  columns: string[];
  empty_message: string;
  current_label: string;
  bulk_actions: { revoke_others: ConfirmedAction; revoke_all: ConfirmedAction } | null;
  sessions: SessionRow[];
};

function RevokeButton({ action }: { action: ConfirmedAction }) {
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!window.confirm(action.confirm)) {
      return;
    }
    router.delete(action.url, {
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
    });
  };

  return (
    <form onSubmit={submit}>
      <button
        type="submit"
        disabled={processing}
      >
        {action.label}
      </button>
    </form>
  );
}

export default function SessionsIndex({
  title,
  back_link: backLink,
  columns,
  empty_message: emptyMessage,
  current_label: currentLabel,
  bulk_actions: bulkActions,
  sessions,
}: SessionsIndexProps) {
  return (
    <section>
      <h1>{title}</h1>
      <Link href={backLink.href}>{backLink.label}</Link>

      {bulkActions ? (
        <div>
          <RevokeButton action={bulkActions.revoke_others} />
          <RevokeButton action={bulkActions.revoke_all} />
        </div>
      ) : null}

      {sessions.length > 0 ? (
        <table>
          <thead>
            <tr>
              {columns.map((column, index) => (
                // Column labels are server text and one of them is deliberately blank, so the
                // position is the only stable key.
                // oxlint-disable-next-line no-array-index-key
                <th key={`${column}-${index}`}>{column}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {sessions.map((session) => (
              <tr key={session.public_id}>
                <td>
                  <div>
                    <span>{session.public_id}</span>
                    {session.current ? <span>{currentLabel}</span> : null}
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
      ) : (
        <p>{emptyMessage}</p>
      )}
    </section>
  );
}
