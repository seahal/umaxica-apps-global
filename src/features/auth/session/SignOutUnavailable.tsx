import { useForm } from "@inertiajs/react";

import Button from "@/components/ui/Button";

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
    <section className="flex flex-col gap-4">
      <h1 className="text-2xl font-bold text-fg">{heading}</h1>
      <p className="text-sm text-fg-muted">{description}</p>

      <form
        action={retry.action}
        method="post"
        onSubmit={submit}
      >
        <Button
          type="submit"
          isDisabled={form.processing}
        >
          {retry.label}
        </Button>
      </form>

      <p className="text-sm">
        {/* A document visit: the destination is another surface entry point with its own guards. */}
        <a
          href={homeLink.href}
          className="text-accent hover:underline"
        >
          {homeLink.label}
        </a>
      </p>
    </section>
  );
}
