import { useForm } from "@inertiajs/react";
import { useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";

// The session-limit management page.
//
// A visitor who reached the concurrent session limit lands here with a restricted session and has
// to revoke one of their active sessions to continue. Selecting a session and cancelling the
// sign-in are both state-changing, so they keep the PATCH and DELETE verbs the route expects.
export type SessionItem = {
  label: string;
  current: boolean;
  current_label: string | null;
  created_at_label: string;
  created_at: string;
  last_used_at_label: string | null;
  last_used_at: string | null;
  ref: string | null;
};

export type ActiveSessionGroup = {
  heading: string;
  count_label: string;
  revoke_label: string;
  items: SessionItem[];
};

export type RestrictedSessionGroup = {
  heading: string;
  items: SessionItem[];
};

export type SessionLimitManagerProps = {
  title: string;
  heading: string;
  description: string;
  alert: string | null;
  notice: string | null;
  restricted_notice: string | null;
  form: {
    action: string;
    submit_label: string;
  };
  cancel: {
    action: string;
    label: string;
    confirm: string;
  };
  active_sessions: ActiveSessionGroup | null;
  restricted_sessions: RestrictedSessionGroup | null;
};

function SessionTimestamps({ item }: { item: SessionItem }) {
  return (
    <>
      <p>
        {item.created_at_label}: {item.created_at}
      </p>
      {item.last_used_at_label && item.last_used_at ? (
        <p>
          {item.last_used_at_label}: {item.last_used_at}
        </p>
      ) : null}
    </>
  );
}

export default function SessionLimitManager({
  heading,
  description,
  alert,
  notice,
  restricted_notice: restrictedNotice,
  form,
  cancel,
  active_sessions: activeSessions,
  restricted_sessions: restrictedSessions,
}: SessionLimitManagerProps) {
  const [selectedRef, setSelectedRef] = useState("");
  const revocation = useForm({ ref: "" });
  const cancellation = useForm({});
  const { confirm, dialog } = useConfirm();

  const submitRevocation = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    // `transform` returns void in Inertia 3, so the request is issued separately rather than
    // chained off it.
    revocation.transform(() => ({ ref: selectedRef }));
    revocation.patch(form.action);
  };

  const submitCancellation = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    confirm({ message: cancel.confirm, confirmLabel: cancel.label }, () => {
      cancellation.delete(cancel.action);
    });
  };

  return (
    <section>
      <h1>{heading}</h1>

      {alert ? (
        <div role="alert">
          <p>{alert}</p>
        </div>
      ) : null}

      {notice ? (
        <div role="status">
          <p>{notice}</p>
        </div>
      ) : null}

      {restrictedNotice ? <p>{restrictedNotice}</p> : null}

      <p>{description}</p>

      <form
        action={form.action}
        method="post"
        onSubmit={submitRevocation}
      >
        {activeSessions ? (
          <div>
            <h2>
              {activeSessions.heading} <span>{activeSessions.count_label}</span>
            </h2>
            <ul>
              {activeSessions.items.map((item, index) => (
                <li key={item.ref ?? `current-${index}`}>
                  <div>
                    <p>
                      {item.label}
                      {item.current_label ? <span>{item.current_label}</span> : null}
                    </p>
                    <SessionTimestamps item={item} />
                  </div>
                  {item.ref ? (
                    <label>
                      <input
                        type="radio"
                        name="ref"
                        value={item.ref}
                        checked={selectedRef === item.ref}
                        onChange={() => setSelectedRef(item.ref ?? "")}
                      />
                      <span>{activeSessions.revoke_label}</span>
                    </label>
                  ) : null}
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        {restrictedSessions ? (
          <div>
            <h2>{restrictedSessions.heading}</h2>
            <ul>
              {restrictedSessions.items.map((item, index) => (
                <li key={`restricted-${index}`}>
                  <div>
                    <p>
                      {item.label}
                      {item.current_label ? <span>{item.current_label}</span> : null}
                    </p>
                    <p>
                      {item.created_at_label}: {item.created_at}
                    </p>
                  </div>
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        <button
          type="submit"
          disabled={revocation.processing}
        >
          {form.submit_label}
        </button>
      </form>

      <form
        action={cancel.action}
        method="post"
        onSubmit={submitCancellation}
      >
        <input
          type="hidden"
          name="_method"
          value="delete"
        />
        <button
          type="submit"
          disabled={cancellation.processing}
        >
          {cancel.label}
        </button>
      </form>
      {dialog}
    </section>
  );
}
