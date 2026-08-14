// React port of `src/controllers/step_up_passkey_controller.js`.
//
// The server issued the challenge and put its options into the page, so the browser only runs
// `navigator.credentials.get` and posts the assertion back to the same endpoint with the same
// parameter names. The form is a native (non-Inertia) POST because that is what the ERB form was:
// the server answers it with a redirect or a re-render, not with an Inertia visit.
import { useRef } from "react";

import { csrfToken } from "@/features/auth/csrf";

import { PASSKEY_MESSAGES, authenticationErrorMessage } from "./messages";
import { useCeremonyMessages } from "./useCeremonyMessages";
import { getAssertion, passkeysSupported } from "./webauthn";

export type StepUpPasskeyFormProps = {
  /** Endpoint the assertion is posted to. */
  action: string;
  /** Parameter scope, e.g. "verification" or "mfa_passkey_form". */
  param_scope: string;
  challenge_id: string;
  /** WebAuthn request options as the server issued them, or null when none was issued. */
  request_options: unknown;
  submit_label: string;
};

export default function StepUpPasskeyForm({
  action,
  param_scope: paramScope,
  challenge_id: challengeId,
  request_options: requestOptions,
  submit_label: submitLabel,
}: StepUpPasskeyFormProps) {
  const formRef = useRef<HTMLFormElement | null>(null);
  const credentialRef = useRef<HTMLInputElement | null>(null);
  const { error, status, showError, showStatus, clearMessages } = useCeremonyMessages();

  const authenticate = async () => {
    clearMessages();

    if (!passkeysSupported()) {
      showError(PASSKEY_MESSAGES.unsupported);
      return;
    }

    if (!requestOptions || !challengeId) {
      showError(PASSKEY_MESSAGES.optionsMissing);
      return;
    }

    try {
      showStatus(PASSKEY_MESSAGES.confirming);
      const credential = await getAssertion(requestOptions);

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
    <form
      ref={formRef}
      action={action}
      method="post"
    >
      <input
        type="hidden"
        name="authenticity_token"
        value={csrfToken()}
        readOnly
      />
      <input
        type="hidden"
        name={`${paramScope}[challenge_id]`}
        value={challengeId}
        readOnly
      />
      <input
        type="hidden"
        name={`${paramScope}[credential_json]`}
        value={credentialJson}
        readOnly
      />

      <button
        type="button"
        onClick={() => void authenticate()}
      >
        {submitLabel}
      </button>

      {error ? <p role="alert">{error}</p> : null}
      {status ? <p>{status}</p> : null}
    </form>
  );
}
