import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import ErrorList from "@/features/base_com/identity/ErrorList";
import type { PageLink, TurnstileProps } from "@/features/base_com/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

// Replaces `app/views/base/com/identity/emails/registrations/new.html.erb`.

export type EmailRegistrationNewProps = {
  title: string;
  back_link: PageLink;
  errors: string[];
  form: { url: string; method: "post"; scope: string; submit_label: string };
  address_label: string;
  address_value: string;
  notifiable: { label: string; description: string; checked: boolean };
  cancel_link: PageLink;
  turnstile: TurnstileProps;
};

export default function EmailRegistrationNew({
  title,
  back_link: backLink,
  errors,
  form,
  address_label: addressLabel,
  address_value: addressValue,
  notifiable,
  cancel_link: cancelLink,
  turnstile,
}: EmailRegistrationNewProps) {
  const [address, setAddress] = useState(addressValue);
  const [notifiableChecked, setNotifiableChecked] = useState(notifiable.checked);
  const [token, setToken] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      form.url,
      {
        [form.scope]: { address, notifiable: notifiableChecked ? "1" : "0" },
        "cf-turnstile-response": token,
      },
      {
        onStart: () => setProcessing(true),
        onFinish: () => setProcessing(false),
      },
    );
  };

  return (
    <section>
      <Link href={backLink.href}>{backLink.label}</Link>
      <h1>{title}</h1>

      <form onSubmit={submit}>
        <ErrorList errors={errors} />

        <div>
          <label htmlFor={`${form.scope}_address`}>{addressLabel}</label>
          <input
            id={`${form.scope}_address`}
            name={`${form.scope}[address]`}
            type="email"
            autoComplete="email"
            required
            value={address}
            onChange={(event) => setAddress(event.target.value)}
          />
        </div>

        <div>
          <input
            id={`${form.scope}_notifiable`}
            name={`${form.scope}[notifiable]`}
            type="checkbox"
            checked={notifiableChecked}
            onChange={(event) => setNotifiableChecked(event.target.checked)}
          />
          <label htmlFor={`${form.scope}_notifiable`}>{notifiable.label}</label>
          <p>{notifiable.description}</p>
        </div>

        <TurnstileWidget
          {...turnstile}
          onToken={setToken}
        />

        <button
          type="submit"
          disabled={processing}
        >
          {form.submit_label}
        </button>
        <Link href={cancelLink.href}>{cancelLink.label}</Link>
      </form>
    </section>
  );
}
