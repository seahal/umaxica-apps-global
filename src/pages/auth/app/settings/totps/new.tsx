// Enrolling a new authenticator app.
//
// The provisioning QR code is rendered by the server into a data URI, the same image the ERB screen
// displayed; the shared secret behind it stays in the session and never becomes a prop. The first
// code the actor types is verified server-side, and an invisible Turnstile token travels with the
// submission exactly as before.
import { useForm } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TextLink from "@/components/ui/TextLink";
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
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <ErrorList
        errors={errorMessages}
        {...(errorHeader === null ? {} : { header: errorHeader })}
      />

      <Card>
        <form
          onSubmit={submit}
          className="flex flex-col gap-5"
        >
          <div className="flex flex-col items-center gap-2">
            <img
              src={qrCodeImage}
              alt="QR Code"
              className="size-48 rounded-lg border border-line bg-white p-2"
            />
            <p className="text-center text-xs break-all text-fg-muted">{qrFallback}</p>
          </div>

          <TextField
            id="totp-title"
            label={formProps.title_label}
            type="text"
            maxLength={32}
            placeholder={formProps.title_placeholder}
            description={formProps.title_hint}
            value={form.data.title}
            onChange={(value) => form.setData("title", value)}
          />

          <div className="flex flex-col gap-1">
            <TextField
              id="totp-first-token"
              label={formProps.first_token_label}
              type="text"
              maxLength={16}
              inputMode="numeric"
              placeholder={formProps.first_token_placeholder}
              description={formProps.first_token_help}
              value={form.data.first_token}
              onChange={(value) => form.setData("first_token", value)}
            />
            <p className="text-xs text-fg-muted">{formProps.first_token_delivery_help}</p>
          </div>

          <TurnstileWidget
            site_key={turnstile.site_key}
            mode={turnstile.mode}
            action={turnstile.action}
            cdata={turnstile.cdata}
            onToken={setToken}
          />

          <div className="flex flex-wrap items-center gap-4">
            <Button
              type="submit"
              isDisabled={form.processing}
            >
              {formProps.submit_label}
            </Button>
            <TextLink
              href={cancelLink.href}
              tone="muted"
              className="text-sm"
            >
              {cancelLink.label}
            </TextLink>
          </div>
        </form>
      </Card>
    </Page>
  );
}
