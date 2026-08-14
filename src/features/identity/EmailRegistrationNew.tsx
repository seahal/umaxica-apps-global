// The address step of adding an email identifier.
import { Link } from "@inertiajs/react";

import FormErrors from "@/features/identity/FormErrors";
import type { LabelledLink, TurnstileProps } from "@/features/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

export type EmailRegistrationNewProps = {
  title: string;
  form: {
    action: string;
    scope: string;
    address_label: string;
    notifiable: boolean;
    notifiable_label: string;
    notifiable_description: string;
    submit: string;
    turnstile: TurnstileProps;
  };
  cancel_link: LabelledLink;
  error_messages: string[];
};

export default function EmailRegistrationNew({
  title,
  form,
  cancel_link: cancelLink,
  error_messages: errorMessages,
}: EmailRegistrationNewProps) {
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
          <label htmlFor={`${form.scope}_address`}>{form.address_label}</label>
          <input
            type="email"
            id={`${form.scope}_address`}
            name={`${form.scope}[address]`}
            autoComplete="email"
            required
          />
        </div>

        <div>
          <input
            type="hidden"
            name={`${form.scope}[notifiable]`}
            value="0"
          />
          <input
            type="checkbox"
            id={`${form.scope}_notifiable`}
            name={`${form.scope}[notifiable]`}
            value="1"
            defaultChecked={form.notifiable}
          />
          <label htmlFor={`${form.scope}_notifiable`}>{form.notifiable_label}</label>
          <p>{form.notifiable_description}</p>
        </div>

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
