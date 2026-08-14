import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import ErrorList from "@/features/base_com/identity/ErrorList";
import type { PageLink, TurnstileProps } from "@/features/base_com/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

// Backs both `new` and `edit` for the base/com secret credential pages: the two ERB templates
// differed only in the one-time secret the create page reveals and in the verb the form uses.

export type SecretCredentialFormProps = {
  title: string;
  description: string;
  errors: { header: string; messages: string[] } | null;
  form: { url: string; method: "post" | "patch"; scope: string; submit_label: string };
  name_label: string;
  name_value: string;
  enabled_label: string;
  enabled: boolean;
  /** Present on the create screen only: the secret is shown once and never fetched again. */
  secret?: { label: string; value: string; one_time_notice: string };
  cancel_link: PageLink;
  turnstile: TurnstileProps;
};

export default function SecretCredentialForm({
  title,
  description,
  errors,
  form,
  name_label: nameLabel,
  name_value: nameValue,
  enabled_label: enabledLabel,
  enabled: enabledInitial,
  secret,
  cancel_link: cancelLink,
  turnstile,
}: SecretCredentialFormProps) {
  const [name, setName] = useState(nameValue);
  const [enabled, setEnabled] = useState(enabledInitial);
  const [token, setToken] = useState("");
  const [processing, setProcessing] = useState(false);

  const nameId = `${form.scope}_name`;
  const enabledId = `${form.scope}_enabled`;

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const payload = {
      [form.scope]: { name, enabled: enabled ? "1" : "0" },
      "cf-turnstile-response": token,
    };
    const options = {
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
    };

    if (form.method === "patch") {
      router.patch(form.url, payload, options);
    } else {
      router.post(form.url, payload, options);
    }
  };

  return (
    <section>
      <h1>{title}</h1>
      <p>{description}</p>

      <form onSubmit={submit}>
        <ErrorList
          errors={errors?.messages ?? []}
          header={errors?.header}
        />

        <div>
          <label htmlFor={nameId}>{nameLabel}</label>
          <input
            id={nameId}
            name={`${form.scope}[name]`}
            type="text"
            value={name}
            onChange={(event) => setName(event.target.value)}
          />
        </div>

        <div>
          <input
            id={enabledId}
            name={`${form.scope}[enabled]`}
            type="checkbox"
            checked={enabled}
            onChange={(event) => setEnabled(event.target.checked)}
          />
          <label htmlFor={enabledId}>{enabledLabel}</label>
        </div>

        {secret ? (
          <div>
            <p>{secret.label}</p>
            <p>{secret.value}</p>
            <p>{secret.one_time_notice}</p>
          </div>
        ) : null}

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
