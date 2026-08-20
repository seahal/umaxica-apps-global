import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import type { IdentityLink } from "@/types/identity";

type Props = {
  title: string;
  description: string;
  code_label: string;
  code_placeholder: string;
  delivery_help: string;
  form: { action: string; submit_label: string };
  cancel_link: IdentityLink;
  errors: string[];
};

export default function TelephoneRegistrationEdit({
  title,
  description,
  code_label: codeLabel,
  code_placeholder: codePlaceholder,
  delivery_help: deliveryHelp,
  form,
  cancel_link: cancelLink,
  errors,
}: Props) {
  const [passCode, setPassCode] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(
      form.action,
      { user_telephone: { pass_code: passCode } },
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
        <label htmlFor="user_telephone_pass_code">{codeLabel}</label>
        <input
          id="user_telephone_pass_code"
          type="text"
          inputMode="numeric"
          pattern="[0-9]*"
          autoComplete="one-time-code"
          placeholder={codePlaceholder}
          value={passCode}
          onChange={(event) => setPassCode(event.target.value)}
        />
        <p>{deliveryHelp}</p>

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
