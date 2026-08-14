// Sign in with an identifier and a secret credential.
//
// The credential is only ever typed into this field; it is never a prop and never comes back from
// the server. A rejected attempt returns one message for every reason, which is what keeps the
// screen from becoming an account-existence oracle.
import { useForm, usePage } from "@inertiajs/react";

import type { TurnstileConfiguration } from "@/features/auth/settings/PasskeyDeleteButton";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import type { SharedProps } from "@/types/inertia";

export type SignInSecretNewProps = {
  title: string;
  action: string;
  pt: string | null;
  ri: string;
  validation_failed_title: string;
  identifier_label: string;
  identifier_placeholder: string;
  secret_label: string;
  submit_label: string;
  back_link: { label: string; href: string };
  turnstile: TurnstileConfiguration;
};

export default function SignInSecretNew({
  title,
  action,
  pt,
  ri,
  validation_failed_title: validationFailedTitle,
  identifier_label: identifierLabel,
  identifier_placeholder: identifierPlaceholder,
  secret_label: secretLabel,
  submit_label: submitLabel,
  back_link: backLink,
  turnstile,
}: SignInSecretNewProps) {
  const { errors } = usePage<SharedProps>().props;
  const messages = Object.values(errors);
  const form = useForm({
    secret_credential_login_form: { identifier: "", secret_credential_value: "" },
    pt: pt ?? "",
    ri: ri,
    "cf-turnstile-response": "",
  });

  const setField = (field: "identifier" | "secret_credential_value", value: string) => {
    form.setData("secret_credential_login_form", {
      ...form.data.secret_credential_login_form,
      [field]: value,
    });
  };

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.post(action);
  };

  return (
    <section className="mx-auto flex w-full max-w-lg flex-col gap-6 p-6">
      <h1>{title}</h1>

      <form onSubmit={submit}>
        {messages.length > 0 ? (
          <div role="alert">
            <h2>{validationFailedTitle}</h2>
            <ul>
              {messages.map((message) => (
                <li key={message}>{message}</li>
              ))}
            </ul>
          </div>
        ) : null}

        <div>
          <label htmlFor="secret_credential_login_form_identifier">{identifierLabel}</label>
          <input
            type="text"
            id="secret_credential_login_form_identifier"
            name="secret_credential_login_form[identifier]"
            placeholder={identifierPlaceholder}
            autoComplete="username"
            value={form.data.secret_credential_login_form.identifier}
            onChange={(event) => setField("identifier", event.target.value)}
          />
        </div>

        <div>
          <label htmlFor="secret_credential_login_form_secret_credential_value">
            {secretLabel}
          </label>
          <input
            type="password"
            id="secret_credential_login_form_secret_credential_value"
            name="secret_credential_login_form[secret_credential_value]"
            placeholder="****************"
            autoComplete="current-password"
            value={form.data.secret_credential_login_form.secret_credential_value}
            onChange={(event) => setField("secret_credential_value", event.target.value)}
          />
        </div>

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
          onToken={(token) => form.setData("cf-turnstile-response", token)}
        />

        <div>
          <button
            type="submit"
            disabled={form.processing}
          >
            {submitLabel}
          </button>
          <a href={backLink.href}>{backLink.label}</a>
        </div>
      </form>
    </section>
  );
}
