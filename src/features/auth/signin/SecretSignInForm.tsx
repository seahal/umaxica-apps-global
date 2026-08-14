// Sign in with a secret credential, and the same page as the second-factor secret challenge.
//
// The two differ only in what the server sends: the second-factor form identifies the actor from the
// pending challenge, so it arrives without an identifier field rather than with one this page would
// hide. Every failure - unknown identifier, wrong secret, failed challenge - comes back as the same
// message, which is what keeps the page from becoming an account-existence oracle.
import { useForm } from "@inertiajs/react";

import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

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
    [key: string]: unknown;
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

  const scoped = data[secretField.scope] as Record<string, string>;
  const setScoped = (field: string, value: string) =>
    setData(secretField.scope, { ...scoped, [field]: value });

  return (
    <section>
      <h1>{title}</h1>

      <form
        onSubmit={(event) => {
          event.preventDefault();
          post(form.action);
        }}
      >
        {formErrors.length > 0 ? (
          <div role="alert">
            <h2>{errorHeading}</h2>
            <ul>
              {formErrors.map((message) => (
                <li key={message}>{message}</li>
              ))}
            </ul>
          </div>
        ) : null}

        {hints ? (
          <div>
            <p>{hints.label}</p>
            <p>{hints.value}</p>
          </div>
        ) : null}

        {identifierField ? (
          <div>
            <label htmlFor={`${identifierField.scope}_${identifierField.field}`}>
              {identifierField.label}
            </label>
            <input
              type="text"
              id={`${identifierField.scope}_${identifierField.field}`}
              name={identifierField.name}
              value={scoped[identifierField.field] ?? ""}
              onChange={(event) => setScoped(identifierField.field, event.target.value)}
              placeholder={identifierField.placeholder}
              autoComplete="username"
            />
          </div>
        ) : null}

        <div>
          <label htmlFor={`${secretField.scope}_${secretField.field}`}>{secretField.label}</label>
          <input
            type="password"
            id={`${secretField.scope}_${secretField.field}`}
            name={secretField.name}
            value={scoped[secretField.field] ?? ""}
            onChange={(event) => setScoped(secretField.field, event.target.value)}
            placeholder={secretField.placeholder}
            autoComplete="current-password"
          />
        </div>

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
          onToken={(token) => setData("cf-turnstile-response", token)}
        />

        <div>
          <button
            type="submit"
            disabled={processing}
          >
            {form.submit_label}
          </button>
          {/* Document visit: leaving the ceremony returns to the method selection page. */}
          <a href={backLink.href}>{backLink.label}</a>
        </div>
      </form>
    </section>
  );
}
