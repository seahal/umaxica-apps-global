import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Checkbox from "@/components/ui/Checkbox";
import ErrorList from "@/components/ui/ErrorList";
import TextField from "@/components/ui/TextField";
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

const LINK = "text-sm text-fg-muted underline-offset-4 hover:text-fg hover:underline";

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
    <section className="flex flex-col gap-6">
      <Link
        href={backLink.href}
        className={LINK}
      >
        {backLink.label}
      </Link>
      <h1 className="text-2xl font-bold text-fg">{title}</h1>

      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        <ErrorList errors={errors} />

        <TextField
          id={`${form.scope}_address`}
          label={addressLabel}
          name={`${form.scope}[address]`}
          type="email"
          autoComplete="email"
          isRequired
          value={address}
          onChange={setAddress}
        />

        <div className="flex flex-col gap-1">
          <Checkbox
            id={`${form.scope}_notifiable`}
            isSelected={notifiableChecked}
            onChange={setNotifiableChecked}
          >
            {notifiable.label}
          </Checkbox>
          <p className="pl-6 text-xs text-fg-muted">{notifiable.description}</p>
        </div>

        <TurnstileWidget
          {...turnstile}
          onToken={setToken}
        />

        <div className="flex items-center gap-4">
          <Button
            type="submit"
            isDisabled={processing}
          >
            {form.submit_label}
          </Button>
          <Link
            href={cancelLink.href}
            className={LINK}
          >
            {cancelLink.label}
          </Link>
        </div>
      </form>
    </section>
  );
}
