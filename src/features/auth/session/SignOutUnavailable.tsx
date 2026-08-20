import { useForm } from "@inertiajs/react";

import type { SignOutLink } from "./SignOutConfirmation";

// Shown when the RP logout transaction could not be issued. The retry keeps the POST verb the
// sign-out route expects rather than degrading to a link.
export type SignOutUnavailableProps = {
  title: string;
  heading: string;
  description: string;
  retry: {
    label: string;
    action: string;
  };
  home_link: SignOutLink;
};

export default function SignOutUnavailable({
  heading,
  description,
  retry,
  home_link: homeLink,
}: SignOutUnavailableProps) {
  const form = useForm({});

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.post(retry.action);
  };

  return (
    <section>
      <h1>{heading}</h1>
      <p>{description}</p>

      <form
        action={retry.action}
        method="post"
        onSubmit={submit}
      >
        <button
          type="submit"
          disabled={form.processing}
        >
          {retry.label}
        </button>
      </form>

      <p>
        {/* A document visit: the destination is another surface entry point with its own guards. */}
        <a href={homeLink.href}>{homeLink.label}</a>
      </p>
    </section>
  );
}
