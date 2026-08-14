// Passkey sign-in for operators.
//
// The identifier is the operator's public id, and the ceremony runs against the same options and
// verification endpoints, with the same rate limits, that the Stimulus controller used.
import PasskeyAuthenticationPanel, {
  type PasskeyAuthenticationPanelProps,
} from "@/features/auth/passkeys/PasskeyAuthenticationPanel";

export type OrgPasskeySignInPageProps = {
  title: string;
  description: string;
  panel: PasskeyAuthenticationPanelProps;
  back_link: { label: string; href: string };
};

export default function OrgPasskeySignInPage({
  title,
  description,
  panel,
  back_link: backLink,
}: OrgPasskeySignInPageProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>

      <PasskeyAuthenticationPanel {...panel} />

      <div>
        <a href={backLink.href}>{backLink.label}</a>
      </div>
    </section>
  );
}
