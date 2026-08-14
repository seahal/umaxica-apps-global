// Registers a new passkey.
//
// The ceremony itself is the shared panel ported from `passkey_registration_controller.js`: it
// solves the invisible Turnstile challenge, asks the options endpoint for a challenge, runs
// `navigator.credentials.create` and posts the attestation to the verification endpoint. Every one
// of those endpoints is unchanged and still enforces its own guards.
import PasskeyRegistrationPanel, {
  type PasskeyRegistrationPanelProps,
} from "@/features/auth/passkeys/PasskeyRegistrationPanel";
import type { SettingsLink } from "@/features/auth/settings/links";

type Props = {
  title: string;
  description: string;
  back_link: SettingsLink;
  cancel_link: SettingsLink;
  panel: PasskeyRegistrationPanelProps;
};

export default function PasskeysNew({
  title,
  description,
  back_link: backLink,
  cancel_link: cancelLink,
  panel,
}: Props) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <a href={backLink.href}>{backLink.label}</a>

      <div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>

      <PasskeyRegistrationPanel {...panel} />

      <a href={cancelLink.href}>{cancelLink.label}</a>
    </section>
  );
}
