// React port of `src/controllers/step_up_passkey_controller.js` for the app second-factor page.
//
// The server issued the challenge and put its options into the page, so the browser only runs
// `navigator.credentials.get` and posts the assertion back to the same endpoint with the same
// parameter names. The submission stays a native document POST because that is what the ERB form
// was: the server answers it with a redirect, not with an Inertia visit, so the form carries the
// same masked per-session authenticity token the ERB form embedded.
import { useRef, useState } from "react";

import { PASSKEY_MESSAGES, authenticationErrorMessage } from "@/features/auth/passkeys/messages";
import { useCeremonyMessages } from "@/features/auth/passkeys/useCeremonyMessages";
import { getAssertion, passkeysSupported } from "@/features/auth/passkeys/webauthn";

import type { SignInLink } from "./types";

export type StepUpPasskeyScreenProps = {
  title: string;
  description: string;
  form: {
    action: string;
    authenticity_token: string;
    /** Rails parameter wrapper, e.g. `mfa_passkey_form`. */
    param_scope: string;
    challenge_id: string;
    /** WebAuthn request options as the server issued them. */
    request_options: unknown;
    submit_label: string;
  };
  back_link: SignInLink;
};

export default function StepUpPasskeyScreen({
  title,
  description,
  form,
  back_link: backLink,
}: StepUpPasskeyScreenProps) {
  const formRef = useRef<HTMLFormElement>(null);
  const [credentialJson, setCredentialJson] = useState("");
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

      setCredentialJson(JSON.stringify(credential));

      showStatus(PASSKEY_MESSAGES.verifying);
      // The value has to be in the DOM before the submit, so submit after the state has flushed.
      queueMicrotask(() => formRef.current?.requestSubmit());
    } catch (caught) {
      showError(authenticationErrorMessage(caught));
    }
  };

  return (
    <section>
      <h1>{title}</h1>
      <p>{description}</p>

      <form
        ref={formRef}
        action={form.action}
        method="post"
        data-turbo="false"
      >
        <input
          type="hidden"
          name="authenticity_token"
          value={form.authenticity_token}
          readOnly
        />
        <input
          type="hidden"
          name={`${form.param_scope}[challenge_id]`}
          value={form.challenge_id}
          readOnly
        />
        <input
          type="hidden"
          name={`${form.param_scope}[credential_json]`}
          value={credentialJson}
          readOnly
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
        {/* Document visit: the challenge menu has its own guards. */}
        <a href={backLink.href}>{backLink.label}</a>
      </div>
    </section>
  );
}
