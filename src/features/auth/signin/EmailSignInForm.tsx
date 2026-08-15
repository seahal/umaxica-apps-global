// Step one of the email sign-in ceremony: submit the address that receives the one-time code.
//
// The endpoint, the verb, the parameter wrapper and the Turnstile challenge are all server
// decisions that arrive as props; the form only collects the address and the token. It never learns
// whether the address is registered - the server answers identically either way.
import { useForm } from "@inertiajs/react";

import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { readString } from "@/lib/payload";

import type { SignInField, SignInLink, SignInTurnstile } from "./types";

export type EmailSignInFormProps = {
  title: string;
  description: string;
  form: {
    action: string;
    method: string;
    pt: string | null;
    address_field: SignInField;
    submit_label: string;
  };
  turnstile: SignInTurnstile;
  form_errors: string[];
  back_link: SignInLink;
};

export default function EmailSignInForm({
  title,
  description,
  form,
  turnstile,
  form_errors: formErrors,
  back_link: backLink,
}: EmailSignInFormProps) {
  const field = form.address_field;
  const { data, setData, post, processing } = useForm<{
    [key: string]: unknown;
    "cf-turnstile-response": string;
    pt: string | null;
  }>({
    [field.scope]: { [field.field]: "" },
    "cf-turnstile-response": "",
    pt: form.pt,
  });

  const value = readString(data[field.scope], field.field) ?? "";
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
          <div
            className="animate-shake"
            role="alert"
          >
            <ul>
              {formErrors.map((message) => (
                <li key={message}>
                  <span>{message}</span>
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        <div>
          <label htmlFor={fieldId}>{field.label}</label>
          <input
            type="email"
            id={fieldId}
            name={field.name}
            value={value}
            onChange={(event) => setData(field.scope, { [field.field]: event.target.value })}
            placeholder={field.placeholder}
            required
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
        </div>
      </form>

      <div>
        {/* Document visit: leaving the ceremony returns to the method selection page. */}
        <a href={backLink.href}>
          <span>{backLink.label}</span>
        </a>
      </div>
    </section>
  );
}
