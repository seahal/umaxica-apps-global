// Registering a new passkey for the operator.
//
// The whole ceremony is the JSON options/verification pair the Stimulus controller drove; the panel
// is its React port and talks to the same two endpoints behind the same step-up and Turnstile
// guards.
import PasskeyRegistrationPanel, {
  type PasskeyRegistrationPanelProps,
} from "@/features/auth/passkeys/PasskeyRegistrationPanel";

export type OrgPasskeyRegistrationPageProps = {
  title: string;
  description: string;
  registration: PasskeyRegistrationPanelProps;
  cancel_link: { label: string; href: string };
};

export default function OrgPasskeyRegistrationPage({
  title,
  description,
  registration,
  cancel_link: cancelLink,
}: OrgPasskeyRegistrationPageProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>

      <PasskeyRegistrationPanel {...registration} />

      <div>
        <a href={cancelLink.href}>{cancelLink.label}</a>
      </div>
    </section>
  );
}
