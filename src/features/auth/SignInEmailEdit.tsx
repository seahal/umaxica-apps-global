// The one-time code step of the email sign-in ceremony.
//
// The resend control talks to the same JSON endpoint with the same opaque resend state the Stimulus
// controller used, so the cooldown stays a server decision. The code itself is only ever typed here;
// it is never rendered into the page.
import { useForm } from "@inertiajs/react";

import OtpResendButton, { type OtpResendMessages } from "@/features/auth/otp/OtpResendButton";
import type { TurnstileConfiguration } from "@/features/auth/settings/PasskeyDeleteButton";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { readString } from "@/lib/payload";

export type SignInEmailEditProps = {
  title: string;
  description: string;
  action: string;
  pt: string | null;
  field_label: string;
  field_placeholder: string;
  submit_label: string;
  delivery_help: string;
  return_link: { label: string; href: string };
  resend: { endpoint: string; state: string; messages: OtpResendMessages };
  turnstile: TurnstileConfiguration;
};

export default function SignInEmailEdit({
  title,
  description,
  action,
  pt,
  field_label: fieldLabel,
  field_placeholder: fieldPlaceholder,
  submit_label: submitLabel,
  delivery_help: deliveryHelp,
  return_link: returnLink,
  resend,
  turnstile,
}: SignInEmailEditProps) {
  const form = useForm({
    user_email: { pass_code: "" },
    pt: pt ?? "",
    "cf-turnstile-response": "",
  });
  const error = readString(form.errors, "pass_code");

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.patch(action);
  };

  return (
    <section className="mx-auto flex w-full max-w-lg flex-col gap-6 p-6">
      <div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>

      <form onSubmit={submit}>
        {error ? (
          <div className="animate-shake">
            <ul>
              <li role="alert">
                <span>{error}</span>
              </li>
            </ul>
          </div>
        ) : null}

        <div>
          <label htmlFor="user_email_pass_code">{fieldLabel}</label>
          <input
            type="text"
            id="user_email_pass_code"
            name="user_email[pass_code]"
            placeholder={fieldPlaceholder}
            maxLength={6}
            autoComplete="one-time-code"
            inputMode="numeric"
            pattern="[0-9]*"
            value={form.data.user_email.pass_code}
            onChange={(event) => form.setData("user_email", { pass_code: event.target.value })}
            required
          />
        </div>

        <OtpResendButton
          endpoint={resend.endpoint}
          state={resend.state}
          messages={resend.messages}
          onResent={() => form.setData("user_email", { pass_code: "" })}
        />

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
        </div>
      </form>

      <p>{deliveryHelp}</p>

      <div>
        <a href={returnLink.href}>
          <span>{returnLink.label}</span>
        </a>
      </div>
    </section>
  );
}
