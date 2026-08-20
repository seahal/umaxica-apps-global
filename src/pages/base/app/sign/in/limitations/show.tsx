import { router, useForm } from "@inertiajs/react";
import type { SyntheticEvent } from "react";

type SessionEntry = {
  session_ref: string;
  restriction_label: string;
  created_label: string;
  last_used_label: string | null;
  revoke_label: string;
};

type Props = {
  title: string;
  heading: string;
  description: string;
  session_label: string;
  error: string | null;
  notice: string | null;
  action: string;
  cancel_action: string;
  submit_label: string;
  cancel_label: string;
  // The server decides which resolution channel this ceremony runs on and names the field.
  resolution: { field: string; value: string };
  sessions: SessionEntry[];
};

export default function SignInLimitationShow({
  title,
  heading,
  description,
  session_label: sessionLabel,
  error,
  notice,
  action,
  cancel_action: cancelAction,
  submit_label: submitLabel,
  cancel_label: cancelLabel,
  resolution,
  sessions,
}: Props) {
  const form = useForm<{ session_ref: string } & Record<string, string>>({
    session_ref: "",
    [resolution.field]: resolution.value,
  });
  const { data, setData, errors, processing } = form;

  const submit = (event: SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.patch(action);
  };

  return (
    <section aria-label={title}>
      <h1>{heading}</h1>

      <p>{description}</p>

      {error ? <p role="alert">{error}</p> : null}
      {notice ? <p>{notice}</p> : null}
      {errors["session_ref"] ? <p role="alert">{errors["session_ref"]}</p> : null}

      <form onSubmit={submit}>
        <ul>
          {sessions.map((entry) => (
            <li key={entry.session_ref}>
              <p>
                {sessionLabel} <span>{entry.restriction_label}</span>
              </p>
              <p>{entry.created_label}</p>
              {entry.last_used_label ? <p>{entry.last_used_label}</p> : null}
              <label>
                <input
                  type="radio"
                  name="session_ref"
                  value={entry.session_ref}
                  checked={data.session_ref === entry.session_ref}
                  onChange={() => setData("session_ref", entry.session_ref)}
                />
                {entry.revoke_label}
              </label>
            </li>
          ))}
        </ul>

        <button
          type="submit"
          disabled={processing}
        >
          {submitLabel}
        </button>
      </form>

      <button
        type="button"
        onClick={() => router.delete(cancelAction)}
      >
        {cancelLabel}
      </button>
    </section>
  );
}
