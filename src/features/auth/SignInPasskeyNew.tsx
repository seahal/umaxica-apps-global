// Sign in with a passkey.
//
// The ceremony is the shared panel ported from the Stimulus controller; this screen frames it with
// the copy and the way back that the server resolved.
import PasskeyAuthenticationPanel, {
  type PasskeyAuthenticationPanelProps,
} from "@/features/auth/passkeys/PasskeyAuthenticationPanel";

export type SignInPasskeyNewProps = {
  title: string;
  description: string;
  panel: PasskeyAuthenticationPanelProps;
  back_link: { label: string; href: string };
};

export default function SignInPasskeyNew({
  title,
  description,
  panel,
  back_link: backLink,
}: SignInPasskeyNewProps) {
  return (
    <section className="mx-auto flex w-full max-w-lg flex-col gap-6 p-6">
      <div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>

      <PasskeyAuthenticationPanel {...panel} />

      <a href={backLink.href}>{backLink.label}</a>
    </section>
  );
}
