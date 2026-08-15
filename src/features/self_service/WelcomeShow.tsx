// The welcome screen a surface shows once, before handing over to its dashboard.
//
// Where "next" goes is a server decision: the welcome sequence resolves it and sends the finished
// destination, so the page never guesses the next step.
import { Link } from "@inertiajs/react";

import CredentialWarning from "@/features/identity/CredentialWarning";
import type { CredentialWarningProps } from "@/features/identity/CredentialWarning";

export type WelcomeShowProps = {
  title: string;
  next_link: { label: string; href: string };
  /** Absent unless the server decided this actor should be prompted to add a credential. */
  credential_warning?: CredentialWarningProps | null;
};

export default function WelcomeShow({
  title,
  next_link: nextLink,
  credential_warning: credentialWarning = null,
}: WelcomeShowProps) {
  return (
    <section>
      <h1>{title}</h1>

      {credentialWarning ? <CredentialWarning {...credentialWarning} /> : null}

      <p>
        <Link href={nextLink.href}>{nextLink.label}</Link>
      </p>
    </section>
  );
}
