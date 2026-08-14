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
    <section>
      <h1>{heading}</h1>

      {description ? <p>{description}</p> : null}

      <p>
        {/* A document visit: the destination is another surface entry point with its own guards. */}
        <a href={homeLink.href}>{homeLink.label}</a>
      </p>
    </section>
  );
}
