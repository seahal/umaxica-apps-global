// The sign-out confirmation screen, replacing `app/views/base/shared/sign_outs/edit.html.erb`.
//
// Whether a session is still active is a server decision: `form` is absent when there is nothing
// left to sign out of, so the button cannot be offered by the client on its own.
import { Link } from "@inertiajs/react";

import { csrfToken } from "@/lib/csrf";

export type SignOutConfirmationForm = {
  action: string;
  submit: string;
  logout_challenge: string | null;
  confirm_description: string;
};

export type SignOutConfirmationProps = {
  title: string;
  active: boolean;
  description: string;
  form: SignOutConfirmationForm | null;
  home_link: { label: string; href: string };
};

export default function SignOutConfirmation({
  title,
  description,
  form,
  home_link: homeLink,
}: SignOutConfirmationProps) {
  return (
    <section>
      <h1>{title}</h1>
      <p>{description}</p>

      {form ? (
        // A full document POST, as the ERB form was: sign-out ends the session the Inertia app
        // runs in, so the response is a navigation rather than a page swap.
        <form
          action={form.action}
          method="post"
          data-turbo="false"
        >
          <input
            type="hidden"
            name="authenticity_token"
            value={csrfToken()}
          />
          {form.logout_challenge ? (
            <input
              type="hidden"
              name="logout_challenge"
              value={form.logout_challenge}
              readOnly
            />
          ) : null}
          <input
            type="submit"
            value={form.submit}
          />
          <noscript>
            <p>{form.confirm_description}</p>
          </noscript>
        </form>
      ) : null}

      <p>
        <Link href={homeLink.href}>{homeLink.label}</Link>
      </p>
    </section>
  );
}
