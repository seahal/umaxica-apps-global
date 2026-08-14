// The one-time-code step of a base identity registration.
//
// The form posts as a document with the verb the route expects, because the server answers a wrong
// code by re-rendering this page and a correct one with a redirect that may leave this host.
import { Link } from "@inertiajs/react";

import FormErrors from "@/features/identity/FormErrors";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

export type OtpVerificationProps = {
  title: string;
  description: string;
  delivery_help: string;
  form: {
    action: string;
    scope: string;
    code_label: string;
    code_placeholder: string;
    submit: string;
    turnstile: {
      site_key: string;
      mode: "render" | "execute";
      action: string | null;
      cdata: string | null;
    };
  };
  cancel_link: { label: string; href: string };
  error_messages: string[];
};

export default function OtpVerification({
  title,
  description,
  delivery_help: deliveryHelp,
  form,
  cancel_link: cancelLink,
  error_messages: errorMessages,
}: OtpVerificationProps) {
  const fieldId = `${form.scope}_pass_code`;

  return (
    <section>
      <h1>{title}</h1>
      <p>{description}</p>

      <form
        action={form.action}
        method="post"
        data-turbo="false"
      >
        <input
          type="hidden"
          name="_method"
          value="patch"
        />
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
        />

        <FormErrors messages={errorMessages} />

        <div>
          <label htmlFor={fieldId}>{form.code_label}</label>
          <input
            type="text"
            id={fieldId}
            name={`${form.scope}[pass_code]`}
            placeholder={form.code_placeholder}
            autoComplete="one-time-code"
            inputMode="numeric"
            pattern="[0-9]*"
          />
        </div>

        <p>{deliveryHelp}</p>

        <TurnstileWidget
          site_key={form.turnstile.site_key}
          mode={form.turnstile.mode}
          action={form.turnstile.action}
          cdata={form.turnstile.cdata}
        />

        <input
          type="submit"
          value={form.submit}
        />
      </form>

      <div>
        <Link href={cancelLink.href}>{cancelLink.label}</Link>
      </div>
    </section>
  );
}
