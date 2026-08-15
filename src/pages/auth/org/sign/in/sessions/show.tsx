// Session-limit management for an operator whose sign-in exceeded the concurrent session limit.
//
// Both forms are document submissions, as the ERB forms were: PATCH revokes the selected session
// and may promote the restricted one, DELETE cancels the ceremony and signs the operator out. The
// value on each choice is the server's signed reference, which is all the server accepts.
import { useConfirm } from "@/components/ConfirmDialog";
import { csrfToken } from "@/features/auth/csrf";

type SessionRow = {
  ref: string;
  digest: string;
  created_at: string | null;
  last_used_at: string | null;
};

export type OrgSessionLimitPageProps = {
  title: string;
  heading: string;
  description: string;
  form_action: string;
  active_sessions_heading: string;
  session_label: string;
  created_at_label: string;
  last_used_label: string;
  no_sessions: string;
  submit_label: string;
  back_link: { label: string; href: string };
  cancel_logout_label: string;
  cancel_logout_confirm: string;
  sessions: SessionRow[];
};

export default function OrgSessionLimitPage({
  heading,
  description,
  form_action: formAction,
  active_sessions_heading: activeSessionsHeading,
  session_label: sessionLabel,
  created_at_label: createdAtLabel,
  last_used_label: lastUsedLabel,
  no_sessions: noSessions,
  submit_label: submitLabel,
  back_link: backLink,
  cancel_logout_label: cancelLogoutLabel,
  cancel_logout_confirm: cancelLogoutConfirm,
  sessions,
}: OrgSessionLimitPageProps) {
  const { confirm, dialog } = useConfirm();

  // The cancellation is held back until the operator accepts, then replayed with `submit()`, which
  // sends the same document DELETE without running this handler again.
  const submitCancellation = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    confirm({ message: cancelLogoutConfirm, confirmLabel: cancelLogoutLabel }, () => form.submit());
  };

  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <div>
        <h1>{heading}</h1>
        <p>{description}</p>
      </div>

      <form
        action={formAction}
        method="post"
      >
        <input
          type="hidden"
          name="_method"
          value="patch"
          readOnly
        />
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
          readOnly
        />

        <h2>{activeSessionsHeading}</h2>

        {sessions.length > 0 ? (
          <div>
            {sessions.map((session) => (
              <label
                key={session.ref}
                data-session-checkbox
                className="ring-2 ring-transparent checked:ring-amber-500"
              >
                <input
                  type="radio"
                  name="ref"
                  value={session.ref}
                />
                <div>
                  <div>
                    <span>
                      {sessionLabel} #{session.digest}
                    </span>
                  </div>
                  <div>
                    <span>
                      {createdAtLabel}: {session.created_at}
                    </span>
                    {session.last_used_at ? (
                      <span>
                        {lastUsedLabel}: {session.last_used_at}
                      </span>
                    ) : null}
                  </div>
                </div>
              </label>
            ))}
          </div>
        ) : (
          <p>{noSessions}</p>
        )}

        <div>
          <input
            type="submit"
            value={submitLabel}
          />
          <a href={backLink.href}>{backLink.label}</a>
        </div>
      </form>

      <form
        action={formAction}
        method="post"
        onSubmit={submitCancellation}
      >
        <input
          type="hidden"
          name="_method"
          value="delete"
          readOnly
        />
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
          readOnly
        />
        <button type="submit">{cancelLogoutLabel}</button>
      </form>
      {dialog}
    </section>
  );
}
