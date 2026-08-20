// Enrolling a new authenticator app.
//
// The provisioning QR code is rendered by the server into a data URI, the same image the ERB screen
// displayed; the shared secret behind it stays in the session and never becomes a prop. The first
// code the actor types is verified server-side, and an invisible Turnstile token travels with the
// submission exactly as before.
import { useForm } from "@inertiajs/react";
import { useState } from "react";

import type { SettingsLink, SettingsTurnstile } from "@/features/auth/settings/links";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

type Props = {
  title: string;
  description: string;
  back_link: SettingsLink;
  qr_code_image: string;
  qr_fallback: string;
  form: {
    action: string;
    scope: string;
    title_label: string;
    title_placeholder: string;
    title_hint: string;
    title: string | null;
    first_token_label: string;
    first_token_placeholder: string;
    first_token_help: string;
    first_token_delivery_help: string;
    submit_label: string;
  };
  cancel_link: SettingsLink;
  turnstile: SettingsTurnstile;
  error_header: string | null;
  error_messages: string[];
};

export default function TotpsNew({
  title,
  description,
  back_link: backLink,
  qr_code_image: qrCodeImage,
  qr_fallback: qrFallback,
  form: formProps,
  cancel_link: cancelLink,
  turnstile,
  error_header: errorHeader,
  error_messages: errorMessages,
}: Props) {
  const [token, setToken] = useState("");
  const form = useForm({ title: formProps.title ?? "", first_token: "" });

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.transform((data) => ({
      [formProps.scope]: data,
      "cf-turnstile-response": token,
    }));
    form.post(formProps.action);
  };

  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <a href={backLink.href}>{backLink.label}</a>

      <div>
        <h3>{title}</h3>
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
        <div>
          <img
            src={qrCodeImage}
            alt="QR Code"
          />
          <p>{qrFallback}</p>
        </div>

        <div>
          <label htmlFor="totp-title">{formProps.title_label}</label>
          <input
            type="text"
            id="totp-title"
            maxLength={32}
            placeholder={formProps.title_placeholder}
            value={form.data.title}
            onChange={(event) => form.setData("title", event.target.value)}
          />
          <p>{formProps.title_hint}</p>
        </div>

        <div>
          <label htmlFor="totp-first-token">{formProps.first_token_label}</label>
          <input
            type="text"
            id="totp-first-token"
            maxLength={16}
            inputMode="numeric"
            placeholder={formProps.first_token_placeholder}
            value={form.data.first_token}
            onChange={(event) => form.setData("first_token", event.target.value)}
          />
          <p>{formProps.first_token_help}</p>
          <p>{formProps.first_token_delivery_help}</p>
        </div>

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
          onToken={setToken}
        />

        <a href={cancelLink.href}>{cancelLink.label}</a>
        <input
          type="submit"
          value={formProps.submit_label}
          disabled={form.processing}
        />
      </form>
    </section>
  );
}
