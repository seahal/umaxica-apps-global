import { router } from "@inertiajs/react";
// Promotional email unsubscribe confirmation.
//
// The page is reached with a signed token instead of a session, so the token is round-tripped
// through the form and the server re-validates it; the challenge token is validated there too.
import { useState } from "react";

import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

export type PreferenceEmailUnsubscribeProps = {
  title: string;
  heading: string;
  promotional: boolean;
  description: string;
  form: {
    action: string;
    token: string;
    submit_label: string;
    turnstile_site_key: string;
  } | null;
};

export default function PreferenceEmailUnsubscribe({
  heading,
  promotional,
  description,
  form,
}: PreferenceEmailUnsubscribeProps) {
  const [challenge, setChallenge] = useState("");

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!form) {
      return;
    }

    router.delete(form.action, {
      data: { token: form.token, "cf-turnstile-response": challenge },
    });
  };

  return (
    <section>
      <h1>{heading}</h1>
      <p>{description}</p>

      {promotional && form ? (
        <form
          onSubmit={submit}
          method="post"
        >
          <input
            type="hidden"
            name="token"
            value={form.token}
            readOnly
          />
          <TurnstileWidget
            site_key={form.turnstile_site_key}
            onToken={setChallenge}
          />
          <input
            type="submit"
            value={form.submit_label}
          />
        </form>
      ) : null}
    </section>
  );
}
