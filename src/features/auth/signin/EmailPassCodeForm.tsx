// Step two of the email sign-in ceremony: enter the one-time code that was delivered.
//
// The code itself never reaches this page - only the field that collects it. Whether the code is
// correct, how many attempts remain, and whether the account is locked are all decided by the
// server, which re-renders this page with the resulting messages.
import { useForm } from "@inertiajs/react";
import { useRef } from "react";

import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { readString } from "@/lib/payload";

import OtpResendButton, { type OtpResend } from "./OtpResendButton";
import type { SignInLink, SignInTurnstile } from "./types";

export type EmailPassCodeField = {
  scope: string;
  field: string;
  name: string;
  label: string;
  placeholder: string;
  max_length: number;
  autocomplete: string;
  inputmode: "numeric";
  pattern: string;
};

export type EmailPassCodeFormProps = {
  title: string;
  description: string;
  form: {
    action: string;
    method: string;
    pt: string | null;
    pass_code_field: EmailPassCodeField;
    submit_label: string;
  };
  otp_resend: OtpResend;
  turnstile: SignInTurnstile;
  form_errors: string[];
  delivery_help: string;
  back_link: SignInLink;
};

export default function EmailPassCodeForm({
  title,
  description,
  form,
  otp_resend: otpResend,
  turnstile,
  form_errors: formErrors,
  delivery_help: deliveryHelp,
  back_link: backLink,
}: EmailPassCodeFormProps) {
  const field = form.pass_code_field;
  const input = useRef<HTMLInputElement>(null);
  const { data, setData, patch, processing } = useForm<{
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
          patch(form.action);
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
            ref={input}
            type="text"
            id={fieldId}
            name={field.name}
            value={value}
            onChange={(event) => setData(field.scope, { [field.field]: event.target.value })}
            placeholder={field.placeholder}
            maxLength={field.max_length}
            autoComplete={field.autocomplete}
            inputMode={field.inputmode}
            pattern={field.pattern}
            required
          />
        </div>

        <OtpResendButton
          resend={otpResend}
          onResent={() => {
            setData(field.scope, { [field.field]: "" });
            input.current?.focus();
          }}
        />

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

      <p>{deliveryHelp}</p>

      <div>
        {/* Document visit: restarting the ceremony issues a new code. */}
        <a href={backLink.href}>
          <span>{backLink.label}</span>
        </a>
      </div>
    </section>
  );
}
