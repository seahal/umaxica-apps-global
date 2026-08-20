import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import ErrorList from "@/features/base_com/identity/ErrorList";
import type { PageLink, TurnstileProps } from "@/features/base_com/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

// The delivered-code step of the email and telephone registration ceremonies. Both ERB templates
// submitted the same shape: a one-time code, an optional verification token, and a challenge.

export type OtpCodeFormProps = {
  title: string;
  description: string;
  errors: string[];
  form: { url: string; method: "patch"; scope: string; submit_label: string };
  verification_token?: string | null;
  code_label: string;
  code_placeholder: string;
  delivery_help: string;
  cancel_link: PageLink;
  turnstile: TurnstileProps;
};

export default function OtpCodeForm({
  title,
  description,
  errors,
  form,
  verification_token: verificationToken,
  code_label: codeLabel,
  code_placeholder: codePlaceholder,
  delivery_help: deliveryHelp,
  cancel_link: cancelLink,
  turnstile,
}: OtpCodeFormProps) {
  const [passCode, setPassCode] = useState("");
  const [token, setToken] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(
      form.url,
      {
        [form.scope]: {
          pass_code: passCode,
          ...(verificationToken ? { token: verificationToken } : {}),
        },
        "cf-turnstile-response": token,
      },
      {
        onStart: () => setProcessing(true),
        onFinish: () => setProcessing(false),
      },
    );
  };

  return (
    <section>
      <h1>{title}</h1>
      <p>{description}</p>

      <form onSubmit={submit}>
        <ErrorList errors={errors} />

        {verificationToken ? (
          <input
            type="hidden"
            name={`${form.scope}[token]`}
            value={verificationToken}
            readOnly
          />
        ) : null}

        <div>
          <label htmlFor={`${form.scope}_pass_code`}>{codeLabel}</label>
          <input
            id={`${form.scope}_pass_code`}
            name={`${form.scope}[pass_code]`}
            type="text"
            placeholder={codePlaceholder}
            autoComplete="one-time-code"
            inputMode="numeric"
            pattern="[0-9]*"
            value={passCode}
            onChange={(event) => setPassCode(event.target.value)}
          />
        </div>

        <p>{deliveryHelp}</p>

        <TurnstileWidget
          {...turnstile}
          onToken={setToken}
        />

        <button
          type="submit"
          disabled={processing}
        >
          {form.submit_label}
        </button>
      </form>

      <Link href={cancelLink.href}>{cancelLink.label}</Link>
    </section>
  );
}
