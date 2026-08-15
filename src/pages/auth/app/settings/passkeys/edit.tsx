// Renames or removes one registered passkey.
//
// Both submissions keep the verb the route expects and carry an invisible Turnstile token, as the
// ERB forms did. Validation failures come back as a re-rendered page carrying the messages the
// model produced.
import { router, useForm } from "@inertiajs/react";
import { useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import type { SettingsLink, SettingsTurnstile } from "@/features/auth/settings/links";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

type Props = {
  title: string;
  description: string;
  back_link: SettingsLink;
  form: {
    action: string;
    scope: string;
    description_label: string;
    description: string | null;
    submit_label: string;
  };
  cancel_link: SettingsLink;
  destroy: { action: string; submit_label: string; confirm_message: string };
  turnstile: SettingsTurnstile;
  error_header: string | null;
  error_messages: string[];
};

export default function PasskeysEdit({
  title,
  description,
  back_link: backLink,
  form: formProps,
  cancel_link: cancelLink,
  destroy,
  turnstile,
  error_header: errorHeader,
  error_messages: errorMessages,
}: Props) {
  const [token, setToken] = useState("");
  const form = useForm({ description: formProps.description ?? "" });
  const { confirm, dialog } = useConfirm();

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.transform((data) => ({
      [formProps.scope]: data,
      "cf-turnstile-response": token,
    }));
    form.patch(formProps.action);
  };

  const remove = () => {
    confirm(
      {
        message: destroy.confirm_message,
        confirmLabel: destroy.submit_label,
        cancelLabel: cancelLink.label,
      },
      () => {
        router.delete(destroy.action, { data: { "cf-turnstile-response": token } });
      },
    );
  };

  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <a href={backLink.href}>{backLink.label}</a>

      <div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>

      {errorHeader ? (
        <div role="alert">
          <h3>{errorHeader}</h3>
          <ul>
            {errorMessages.map((message) => (
              <li key={message}>{message}</li>
            ))}
          </ul>
        </div>
      ) : null}

      <form onSubmit={submit}>
        <label htmlFor="passkey-description">{formProps.description_label}</label>
        <input
          type="text"
          id="passkey-description"
          maxLength={100}
          value={form.data.description}
          onChange={(event) => form.setData("description", event.target.value)}
        />

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
          onToken={setToken}
        />

        <input
          type="submit"
          value={formProps.submit_label}
          disabled={form.processing}
        />
        <a href={cancelLink.href}>{cancelLink.label}</a>
      </form>

      <button
        type="button"
        onClick={remove}
      >
        {destroy.submit_label}
      </button>
      {dialog}
    </section>
  );
}
