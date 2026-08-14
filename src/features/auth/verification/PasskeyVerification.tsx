// Step-up verification with a passkey. React port of the `step-up-passkey` Stimulus controller.
//
// The server issued the challenge and put its options in the page, so the browser only runs
// `navigator.credentials.get` and posts the assertion back to the same endpoint under the same
// parameter names. The form stays a document POST, as the ERB form was: the server answers it with
// the step-up completion hand-off document or with this page re-rendered, not with an Inertia visit.
import { useRef } from "react";

import { PASSKEY_MESSAGES, authenticationErrorMessage } from "@/features/auth/passkeys/messages";
import { useCeremonyMessages } from "@/features/auth/passkeys/useCeremonyMessages";
import { getAssertion, passkeysSupported } from "@/features/auth/passkeys/webauthn";

import type { VerificationFormBase, VerificationLink } from "./types";
import VerificationErrors from "./VerificationErrors";
import VerificationFormFields from "./VerificationFormFields";

export type PasskeyVerificationForm = VerificationFormBase & {
  challenge_id: string;
  /** WebAuthn request options as the server issued them, or null when none was issued. */
  request_options: unknown;
};

export type PasskeyVerificationProps = {
  title: string;
  heading: string;
  description: string;
  errors: string[];
  form: PasskeyVerificationForm;
  back: VerificationLink;
};

export default function PasskeyVerification({
  heading,
  description,
  errors,
  form,
  back,
}: PasskeyVerificationProps) {
  const formRef = useRef<HTMLFormElement | null>(null);
  const credentialRef = useRef<HTMLInputElement | null>(null);
  const { error, status, showError, showStatus, clearMessages } = useCeremonyMessages();

  const authenticate = async () => {
    clearMessages();

    if (!passkeysSupported()) {
      showError(PASSKEY_MESSAGES.unsupported);
      return;
    }

    if (!form.request_options || !form.challenge_id) {
      showError(PASSKEY_MESSAGES.optionsMissing);
      return;
    }

    try {
      showStatus(PASSKEY_MESSAGES.confirming);
      const credential = await getAssertion(form.request_options);

      // Written straight into the field, as the Stimulus target was, so the value is in the DOM
      // before `requestSubmit` rather than one React render later.
      if (credentialRef.current) {
        credentialRef.current.value = JSON.stringify(credential);
      }

      showStatus(PASSKEY_MESSAGES.verifying);
      formRef.current?.requestSubmit();
    } catch (caught) {
      showError(authenticationErrorMessage(caught));
    }
  };

  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <h1>{heading}</h1>
      <p>{description}</p>

      <VerificationErrors errors={errors} />

      <form
        ref={formRef}
        action={form.action}
        method="post"
      >
        <VerificationFormFields
          csrf_token={form.csrf_token}
          scope={form.scope}
          pt={form.pt}
        />
        <input
          type="hidden"
          name="verification[challenge_id]"
          value={form.challenge_id}
          readOnly
        />
        <input
          ref={credentialRef}
          type="hidden"
          name="verification[credential_json]"
          defaultValue=""
        />

        <button
          type="button"
          onClick={() => void authenticate()}
        >
          {form.submit_label}
        </button>

        {error ? <p role="alert">{error}</p> : null}
        {status ? <p>{status}</p> : null}
      </form>

      <div>
        <a href={back.href}>{back.label}</a>
      </div>
    </section>
  );
}
