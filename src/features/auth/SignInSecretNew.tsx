// Sign in with an identifier and a secret credential.
//
// The credential is only ever typed into this field; it is never a prop and never comes back from
// the server. A rejected attempt returns one message for every reason, which is what keeps the
// screen from becoming an account-existence oracle.
import { useForm, usePage } from "@inertiajs/react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import type { TurnstileConfiguration } from "@/features/auth/settings/PasskeyDeleteButton";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

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
  const { errors } = usePage().props;
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

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.post(action);
  };

  return (
    <Page
      title={title}
      width="narrow"
    >
      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        {messages.length > 0 ? (
          <div
            role="alert"
            className="animate-shake rounded-lg border border-line bg-surface-muted p-4"
          >
            <h2 className="text-sm font-semibold text-fg">{validationFailedTitle}</h2>
            <ul className="mt-1 flex flex-col gap-1 text-sm text-danger">
              {messages.map((message) => (
                <li key={message}>{message}</li>
              ))}
            </ul>
          </div>
        ) : null}

        <TextField
          label={identifierLabel}
          placeholder={identifierPlaceholder}
          autoComplete="username"
          name="secret_credential_login_form[identifier]"
          value={form.data.secret_credential_login_form.identifier}
          onChange={(value) => setField("identifier", value)}
        />

        <TextField
          label={secretLabel}
          type="password"
          placeholder="****************"
          autoComplete="current-password"
          name="secret_credential_login_form[secret_credential_value]"
          value={form.data.secret_credential_login_form.secret_credential_value}
          onChange={(value) => setField("secret_credential_value", value)}
        />

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
          onToken={(token) => form.setData("cf-turnstile-response", token)}
        />

        <div className="flex items-center gap-4">
          <Button
            type="submit"
            isDisabled={form.processing}
          >
            {submitLabel}
          </Button>
          <a
            href={backLink.href}
            className="text-sm text-fg-muted underline-offset-4 hover:text-fg hover:underline"
          >
            {backLink.label}
          </a>
        </div>
      </form>
    </Page>
  );
}
