// The second-factor screen for a time-based one-time code.
//
// The Turnstile challenge runs invisibly here, as the stealth partial did, so the actor is not asked
// to solve anything on top of the code. Whether the code is valid, replayed, or exhausted is decided
// by the server, which re-renders this page with the resulting messages.
import { useForm } from "@inertiajs/react";

import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

import type { SignInLink, SignInTurnstile } from "./types";

export type TotpChallengeField = {
  scope: string;
  field: string;
  name: string;
  label: string;
  placeholder: string;
  max_length: number;
  inputmode: "numeric";
  help: string;
};

export type TotpChallengeFormProps = {
  title: string;
  description: string;
  form: {
    action: string;
    method: string;
    token_field: TotpChallengeField;
    submit_label: string;
  };
  error_heading: string;
  form_errors: string[];
  turnstile: SignInTurnstile;
  back_link: SignInLink;
};

export default function TotpChallengeForm({
  title,
  description,
  form,
  error_heading: errorHeading,
  form_errors: formErrors,
  turnstile,
  back_link: backLink,
}: TotpChallengeFormProps) {
  const field = form.token_field;
  const { data, setData, post, processing } = useForm<{
    [key: string]: unknown;
    "cf-turnstile-response": string;
  }>({
    [field.scope]: { [field.field]: "" },
    "cf-turnstile-response": "",
  });

  const value = (data[field.scope] as Record<string, string>)[field.field] ?? "";
  const fieldId = `${field.scope}_${field.field}`;

  return (
    <section>
      <div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>

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

        <div>
          <label htmlFor={fieldId}>{field.label}</label>
          <input
            type="text"
            id={fieldId}
            name={field.name}
            value={value}
            onChange={(event) => setData(field.scope, { [field.field]: event.target.value })}
            placeholder={field.placeholder}
            maxLength={field.max_length}
            inputMode={field.inputmode}
          />
          <p>{field.help}</p>
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
          {/* Document visit: the challenge menu has its own guards. */}
          <a href={backLink.href}>{backLink.label}</a>
        </div>
      </form>
    </section>
  );
}
