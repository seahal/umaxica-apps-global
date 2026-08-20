import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import DestructiveButton from "@/features/base_com/identity/DestructiveButton";
import ErrorList from "@/features/base_com/identity/ErrorList";
import type { ConfirmedAction, PageLink, TurnstileProps } from "@/features/base_com/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

// Replaces `app/views/base/com/identity/emails/edit.html.erb`.

type Toggle = { label: string; description: string; checked: boolean };

export type EmailEditProps = {
  title: string;
  address: string;
  errors: string[];
  always_on: { label: string; description: string };
  promotional: Toggle;
  notifiable: Toggle;
  form: { url: string; scope: string; submit_label: string };
  destroy: ConfirmedAction;
  cancel_link: PageLink;
  turnstile: TurnstileProps;
};

export default function EmailEdit({
  title,
  address,
  errors,
  always_on: alwaysOn,
  promotional,
  notifiable,
  form,
  destroy,
  cancel_link: cancelLink,
  turnstile,
}: EmailEditProps) {
  const [promotionalChecked, setPromotionalChecked] = useState(promotional.checked);
  const [notifiableChecked, setNotifiableChecked] = useState(notifiable.checked);
  const [token, setToken] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(
      form.url,
      {
        [form.scope]: {
          promotional: promotionalChecked ? "1" : "0",
          notifiable: notifiableChecked ? "1" : "0",
        },
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
      <h1>{title}</h1>
      <p>{address}</p>

      <form onSubmit={submit}>
        <ErrorList errors={errors} />

        <div>
          <p>{alwaysOn.label}</p>
          <p>{alwaysOn.description}</p>
        </div>

        <div>
          <input
            id={`${form.scope}_promotional`}
            name={`${form.scope}[promotional]`}
            type="checkbox"
            checked={promotionalChecked}
            onChange={(event) => setPromotionalChecked(event.target.checked)}
          />
          <label htmlFor={`${form.scope}_promotional`}>{promotional.label}</label>
          <p>{promotional.description}</p>
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
      </form>

      <DestructiveButton action={destroy} />
      <Link href={cancelLink.href}>{cancelLink.label}</Link>
    </section>
  );
}
