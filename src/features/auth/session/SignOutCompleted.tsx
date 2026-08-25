import type { SignOutLink } from "./SignOutConfirmation";

// The sign-out completion notice. The description is optional: the server only sends it when it
// knows when the cleared access token stops being accepted.
export type SignOutCompletedProps = {
  title: string;
  heading: string;
  description: string | null;
  home_link: SignOutLink;
};

export default function SignOutCompleted({
  heading,
  description,
  home_link: homeLink,
}: SignOutCompletedProps) {
  return (
    <section className="flex flex-col gap-4">
      <h1 className="text-2xl font-bold text-fg">{heading}</h1>

      {description ? <p className="text-sm text-fg-muted">{description}</p> : null}

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
