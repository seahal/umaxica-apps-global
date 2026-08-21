import { router } from "@inertiajs/react";
// Promotional email unsubscribe confirmation.
//
// The page is reached with a signed token instead of a session, so the token is round-tripped
// through the form and the server re-validates it; the challenge token is validated there too.
import { useState } from "react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
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
    <Page
      title={heading}
      description={description}
    >
      {promotional && form ? (
        <form
          onSubmit={submit}
          method="post"
          className="flex flex-col gap-4"
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
          <div>
            <Button type="submit">{form.submit_label}</Button>
          </div>
        </form>
      ) : null}
    </Page>
  );
}
