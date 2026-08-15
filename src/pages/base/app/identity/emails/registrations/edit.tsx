import { router } from "@inertiajs/react";
import { useState } from "react";

import type { IdentityLink } from "@/types/identity";

type VerificationForm = {
  action: string;
  code_label: string;
  code_placeholder: string;
  delivery_help: string;
  submit_label: string;
  verification_token: string | null;
};

type Props = {
  title: string;
  description: string;
  cancel_link: IdentityLink;
  form: VerificationForm;
  resend: { label: string; url: string };
  errors: string[];
};

export default function EmailRegistrationEdit({
  title,
  description,
  cancel_link: cancelLink,
  form,
  resend,
  errors,
}: Props) {
  const [passCode, setPassCode] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(
      form.action,
      {
        user_email: {
          pass_code: passCode,
          ...(form.verification_token ? { token: form.verification_token } : {}),
        },
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

      {errors.length > 0 ? (
        <ul role="list">
          {errors.map((message) => (
            <li key={message}>{message}</li>
          ))}
        </ul>
      ) : null}

      <form onSubmit={submit}>
        <label htmlFor="user_email_pass_code">{form.code_label}</label>
        <input
          id="user_email_pass_code"
          type="text"
          inputMode="numeric"
          pattern="[0-9]*"
          autoComplete="one-time-code"
          placeholder={form.code_placeholder}
          value={passCode}
          onChange={(event) => setPassCode(event.target.value)}
        />
        <p>{form.delivery_help}</p>
        <button
          type="submit"
          disabled={processing}
        >
          {form.submit_label}
        </button>
      </form>

      <button
        type="button"
        onClick={() => router.post(resend.url)}
      >
        {resend.label}
      </button>

      <a href={cancelLink.href}>{cancelLink.label}</a>
    </section>
  );
}
