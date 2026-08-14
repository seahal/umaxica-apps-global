// The sign-out completion screen, replacing `app/views/base/shared/sign_outs/complete.html.erb`.
import { Link } from "@inertiajs/react";

export type SignOutCompletionProps = {
  title: string;
  /** Absent when the server has no expiry to report. */
  description: string | null;
  home_link: { label: string; href: string };
};

export default function SignOutCompletion({
  title,
  description,
  home_link: homeLink,
}: SignOutCompletionProps) {
  return (
    <section>
      <h1>{title}</h1>
      {description ? <p>{description}</p> : null}
      <p>
        <Link href={homeLink.href}>{homeLink.label}</Link>
      </p>
    </section>
  );
}
