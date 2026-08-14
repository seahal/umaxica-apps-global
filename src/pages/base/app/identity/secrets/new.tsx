import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import type { IdentityLink } from "@/types/identity";

type SecretForm = {
  action: string;
  name_label: string;
  name: string;
  enabled_label: string;
  submit_label: string;
};

type Props = {
  title: string;
  description: string;
  back_link: IdentityLink;
  cancel_link: IdentityLink;
  form: SecretForm;
  raw_secret_credential: string;
  raw_secret_label: string;
  one_time_notice: string;
  errors: string[];
};

export default function SecretNew({
  title,
  description,
  back_link: backLink,
  cancel_link: cancelLink,
  form,
  raw_secret_credential: rawSecretCredential,
  raw_secret_label: rawSecretLabel,
  one_time_notice: oneTimeNotice,
  errors,
}: Props) {
  const [name, setName] = useState(form.name);
  const [enabled, setEnabled] = useState(false);
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(form.action, {
      data: { user_secret_credential: { name, enabled: enabled ? "1" : "0" } },
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
    });
  };

  return (
    <section>
      <a href={backLink.href}>{backLink.label}</a>

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
        <label htmlFor="user_secret_credential_name">{form.name_label}</label>
        <input
          id="user_secret_credential_name"
          type="text"
          value={name}
          onChange={(event) => setName(event.target.value)}
        />

        <div>
          <input
            id="user_secret_credential_enabled"
            type="checkbox"
            checked={enabled}
            onChange={(event) => setEnabled(event.target.checked)}
          />
          <label htmlFor="user_secret_credential_enabled">{form.enabled_label}</label>
        </div>

        <div>
          <p>{rawSecretLabel}</p>
          <p data-raw-secret>{rawSecretCredential}</p>
          <p>{oneTimeNotice}</p>
        </div>

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
