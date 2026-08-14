// The number step of adding a telephone identifier.
//
// `turnstile` is absent on the route that does not run the challenge, so the widget is rendered
// only when the server sent its configuration.
import { Link } from "@inertiajs/react";

import FormErrors from "@/features/identity/FormErrors";
import type { LabelledLink, TurnstileProps } from "@/features/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

export type TelephoneRegistrationNewProps = {
  title: string;
  form: {
    action: string;
    scope: string;
    number_label: string;
    number_placeholder: string;
    submit: string;
    turnstile?: TurnstileProps;
  };
  cancel_link: LabelledLink;
  error_messages: string[];
};

export default function TelephoneRegistrationNew({
  title,
  form,
  cancel_link: cancelLink,
  error_messages: errorMessages,
}: TelephoneRegistrationNewProps) {
  return (
    <section>
      <h1>{title}</h1>

      <form
        action={form.action}
        method="post"
        data-turbo="false"
      >
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
        />

        <FormErrors messages={errorMessages} />

        <div>
          <label htmlFor={`${form.scope}_raw_number`}>{form.number_label}</label>
          <input
            type="tel"
            id={`${form.scope}_raw_number`}
            name={`${form.scope}[raw_number]`}
            placeholder={form.number_placeholder}
          />
        </div>

        {form.turnstile ? (
          <div>
            <TurnstileWidget
              site_key={form.turnstile.site_key}
              mode={form.turnstile.mode}
              action={form.turnstile.action}
              cdata={form.turnstile.cdata}
            />
          </div>
        ) : null}

        <div>
          <Link href={cancelLink.href}>{cancelLink.label}</Link>
          <input
            type="submit"
            value={form.submit}
          />
        </div>
      </form>
    </section>
  );
}
