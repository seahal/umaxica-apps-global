import { router } from "@inertiajs/react";
import { useState } from "react";

import type { IdentityLink, IdentityPreferenceField } from "@/types/identity";

type RegistrationForm = {
  action: string;
  address_label: string;
  address: string;
  submit_label: string;
  promotional: IdentityPreferenceField;
  notifiable: IdentityPreferenceField;
};

type Props = {
  title: string;
  back_link: IdentityLink;
  cancel_link: IdentityLink;
  form: RegistrationForm;
  errors: string[];
};

export default function EmailRegistrationNew({
  title,
  back_link: backLink,
  cancel_link: cancelLink,
  form,
  errors,
}: Props) {
  const [address, setAddress] = useState(form.address);
  const [promotional, setPromotional] = useState(form.promotional.checked);
  const [notifiable, setNotifiable] = useState(form.notifiable.checked);
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      form.action,
      {
        user_email: {
          address,
          promotional: promotional ? "1" : "0",
          notifiable: notifiable ? "1" : "0",
        },
      },
      {
        onStart: () => setProcessing(true),

        onFinish: () => setProcessing(false),
      },
    );
  };

  return (
    <section>
      <a href={backLink.href}>{backLink.label}</a>

      <h1>{title}</h1>

      {errors.length > 0 ? (
        <ul role="list">
          {errors.map((message) => (
            <li key={message}>{message}</li>
          ))}
        </ul>
      ) : null}

      <form onSubmit={submit}>
        <label htmlFor="user_email_address">{form.address_label}</label>
        <input
          id="user_email_address"
          type="email"
          autoComplete="email"
          required
          value={address}
          onChange={(event) => setAddress(event.target.value)}
        />

        <div>
          <input
            id="user_email_promotional"
            type="checkbox"
            checked={promotional}
            onChange={(event) => setPromotional(event.target.checked)}
          />
          <label htmlFor="user_email_promotional">{form.promotional.label}</label>
          <p>{form.promotional.description}</p>
        </div>

        <div>
          <input
            id="user_email_notifiable"
            type="checkbox"
            checked={notifiable}
            onChange={(event) => setNotifiable(event.target.checked)}
          />
          <label htmlFor="user_email_notifiable">{form.notifiable.label}</label>
          <p>{form.notifiable.description}</p>
        </div>

        <button
          type="submit"
          disabled={processing}
        >
          {form.submit_label}
        </button>
      </form>

      <a href={cancelLink.href}>{cancelLink.label}</a>
    </section>
  );
}
