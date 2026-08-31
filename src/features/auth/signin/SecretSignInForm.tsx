// Sign in with a secret credential, and the same page as the second-factor secret challenge.
//
// The two differ only in what the server sends: the second-factor form identifies the actor from the
// pending challenge, so it arrives without an identifier field rather than with one this page would
// hide. Every failure - unknown identifier, wrong secret, failed challenge - comes back as the same
// message, which is what keeps the page from becoming an account-existence oracle.
import { useForm } from "@inertiajs/react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { readRecord } from "@/lib/payload";

import type { SignInField, SignInLink, SignInTurnstile } from "./types";

export type SecretSignInFormProps = {
  title: string;
  form: {
    action: string;
    method: string;
    pt: string | null;
    ri: string | null;
    identifier_field: SignInField | null;
    secret_field: {
      scope: string;
      field: string;
      name: string;
      label: string;
      placeholder: string;
    };
    submit_label: string;
  };
  hints: { label: string; value: string } | null;
  error_heading: string;
  form_errors: string[];
  turnstile: SignInTurnstile;
  back_link: SignInLink;
};

export default function SecretSignInForm({
  title,
  form,
  hints,
  error_heading: errorHeading,
  form_errors: formErrors,
  turnstile,
  back_link: backLink,
}: SecretSignInFormProps) {
  const { identifier_field: identifierField, secret_field: secretField } = form;
  const { data, setData, post, processing } = useForm<{
    [key: string]: string | null | Record<string, string>;
    "cf-turnstile-response": string;
    pt: string | null;
    ri: string | null;
  }>({
    [secretField.scope]: {
      ...(identifierField ? { [identifierField.field]: "" } : {}),
      [secretField.field]: "",
    },
    "cf-turnstile-response": "",
    pt: form.pt,
    ri: form.ri,
  });

  const scoped = readRecord(data[secretField.scope]);
  const setScoped = (field: string, value: string) =>
    setData(secretField.scope, { ...scoped, [field]: value });

  return (
    <Page
      title={title}
      width="narrow"
    >
      <form
        onSubmit={(event) => {
          event.preventDefault();
          post(form.action);
        }}
        className="flex flex-col gap-4"
      >
        {formErrors.length > 0 ? (
          <div
            role="alert"
            className="animate-shake flex flex-col gap-1 rounded-md border border-danger bg-surface p-3"
          >
            <h2 className="text-sm font-semibold text-danger">{errorHeading}</h2>
            <ul className="flex flex-col gap-1 text-sm text-danger">
              {formErrors.map((message) => (
                <li key={message}>{message}</li>
              ))}
            </ul>
          </div>
        ) : null}

        {hints ? (
          <div className="rounded-md border border-line bg-surface-muted p-3 text-sm text-fg-muted">
            <p className="font-medium text-fg">{hints.label}</p>
            <p>{hints.value}</p>
          </div>
        ) : null}

        {identifierField ? (
          <TextField
            label={identifierField.label}
            name={identifierField.name}
            /* v8 ignore next -- the field is always initialised in useForm */
            value={scoped[identifierField.field] ?? ""}
            onChange={(value) => setScoped(identifierField.field, value)}
            placeholder={identifierField.placeholder}
            autoComplete="username"
          />
        ) : null}

        <TextField
          label={secretField.label}
          type="password"
          name={secretField.name}
          /* v8 ignore next -- the field is always initialised in useForm */
          value={scoped[secretField.field] ?? ""}
          onChange={(value) => setScoped(secretField.field, value)}
          placeholder={secretField.placeholder}
          autoComplete="current-password"
        />

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
          onToken={(token) => setData("cf-turnstile-response", token)}
        />

        <div className="flex items-center gap-4">
          <Button
            type="submit"
            isDisabled={processing}
          >
            {form.submit_label}
          </Button>
          {/* Document visit: leaving the ceremony returns to the method selection page. */}
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
