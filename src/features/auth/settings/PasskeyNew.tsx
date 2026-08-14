// Starts the WebAuthn registration ceremony for a new passkey.
//
// The ceremony itself is the shared panel ported from the Stimulus controller; this screen only
// frames it with the copy and the way back that the server resolved.
import PasskeyRegistrationPanel, {
  type PasskeyRegistrationPanelProps,
} from "@/features/auth/passkeys/PasskeyRegistrationPanel";

export type PasskeyNewProps = {
  title: string;
  description: string;
  panel: PasskeyRegistrationPanelProps;
  cancel_link: { label: string; href: string };
};

export default function PasskeyNew({
  title,
  description,
  panel,
  cancel_link: cancelLink,
}: PasskeyNewProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>

      <PasskeyRegistrationPanel {...panel} />

      <a href={cancelLink.href}>{cancelLink.label}</a>
    </section>
  );
}
