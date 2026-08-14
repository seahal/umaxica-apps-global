// The passkey sign-in page: heading, the ceremony panel, and the way back out.
import PasskeySignInPanel, { type PasskeySignInPanelProps } from "./PasskeySignInPanel";
import type { SignInLink } from "./types";

export type PasskeySignInScreenProps = {
  title: string;
  description: string;
  panel: PasskeySignInPanelProps;
  back_link: SignInLink;
};

export default function PasskeySignInScreen({
  title,
  description,
  panel,
  back_link: backLink,
}: PasskeySignInScreenProps) {
  return (
    <section>
      <div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>

      <PasskeySignInPanel {...panel} />

      <div>
        {/* Document visit: leaving the ceremony returns to the method selection page. */}
        <a href={backLink.href}>{backLink.label}</a>
      </div>
    </section>
  );
}
