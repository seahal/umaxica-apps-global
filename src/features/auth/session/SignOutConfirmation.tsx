import { useForm } from "@inertiajs/react";

// The sign-out confirmation ceremony, shared by the auth surfaces.
//
// Sign-out is destructive, so both the confirmation and the cancellation keep the HTTP verbs the
// Rails routes expect (POST and DELETE). Nothing here is a link.
export type SignOutLink = {
  label: string;
  href: string;
};

export type SignOutConfirmationProps = {
  title: string;
  heading: string;
  active_context: boolean;
  confirm_description: string;
  already_signed_out: string;
  submit_label: string;
  form: {
    action: string;
    logout_challenge: string | null;
  };
  cancel: {
    label: string;
    action: string;
  };
  home_link: SignOutLink;
};

export default function SignOutConfirmation({
  heading,
  active_context: activeContext,
  confirm_description: confirmDescription,
  already_signed_out: alreadySignedOut,
  submit_label: submitLabel,
  form,
  cancel,
  home_link: homeLink,
}: SignOutConfirmationProps) {
  const confirmation = useForm({ logout_challenge: form.logout_challenge ?? "" });
  const cancellation = useForm({});

  const submitConfirmation = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    confirmation.post(form.action);
  };

  const submitCancellation = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    cancellation.delete(cancel.action);
  };

  return (
    <section>
      <h1>{heading}</h1>

      {activeContext ? (
        <>
          <p>{confirmDescription}</p>
          <form
            action={form.action}
            method="post"
            onSubmit={submitConfirmation}
          >
            <button
              type="submit"
              disabled={confirmation.processing}
            >
              {submitLabel}
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
        </>
      ) : (
        <p>{alreadySignedOut}</p>
      )}

      <p>
        {/* A document visit: the destination is another surface entry point with its own guards. */}
        <a href={homeLink.href}>{homeLink.label}</a>
      </p>
    </section>
  );
}
