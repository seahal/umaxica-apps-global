import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import type { IdentityLink } from "@/types/identity";

type Props = {
  title: string;
  description: string;
  help_text: string;
  number_label: string;
  number_placeholder: string;
  form: { action: string; submit_label: string };
  cancel_link: IdentityLink;
  errors: string[];
};

export default function TelephoneRegistrationNew({
  title,
  description,
  help_text: helpText,
  number_label: numberLabel,
  number_placeholder: numberPlaceholder,
  form,
  cancel_link: cancelLink,
  errors,
}: Props) {
  const [rawNumber, setRawNumber] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      form.action,
      { user_telephone: { raw_number: rawNumber } },
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

      {errors.length > 0 ? (
        <ul role="list">
          {errors.map((message) => (
            <li key={message}>{message}</li>
          ))}
        </ul>
      ) : null}

      <form onSubmit={submit}>
        <label htmlFor="user_telephone_raw_number">{numberLabel}</label>
        <input
          id="user_telephone_raw_number"
          type="tel"
          placeholder={numberPlaceholder}
          value={rawNumber}
          onChange={(event) => setRawNumber(event.target.value)}
        />
        <p>{helpText}</p>

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
