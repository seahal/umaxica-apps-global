import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import ErrorList from "@/features/base_com/identity/ErrorList";
import type { PageLink, TurnstileProps } from "@/features/base_com/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

// Replaces `app/views/base/com/identity/telephones/registrations/new.html.erb`.

export type TelephoneRegistrationNewProps = {
  title: string;
  description: string;
  errors: string[];
  form: { url: string; method: "post"; scope: string; submit_label: string };
  number_label: string;
  number_placeholder: string;
  help_text: string;
  cancel_link: PageLink;
  turnstile: TurnstileProps;
};

export default function TelephoneRegistrationNew({
  title,
  description,
  errors,
  form,
  number_label: numberLabel,
  number_placeholder: numberPlaceholder,
  help_text: helpText,
  cancel_link: cancelLink,
  turnstile,
}: TelephoneRegistrationNewProps) {
  const [rawNumber, setRawNumber] = useState("");
  const [token, setToken] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      form.url,
      {
        [form.scope]: { raw_number: rawNumber },
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

        <div>
          <label htmlFor={`${form.scope}_raw_number`}>{numberLabel}</label>
          <input
            id={`${form.scope}_raw_number`}
            name={`${form.scope}[raw_number]`}
            type="tel"
            placeholder={numberPlaceholder}
            value={rawNumber}
            onChange={(event) => setRawNumber(event.target.value)}
          />
          <p>{helpText}</p>
        </div>

        <TurnstileWidget
          {...turnstile}
          onToken={setToken}
        />

        <div>
          <Link href={cancelLink.href}>{cancelLink.label}</Link>
          <button
            type="submit"
            disabled={processing}
          >
            {form.submit_label}
          </button>
        </div>
      </form>
    </section>
  );
}
