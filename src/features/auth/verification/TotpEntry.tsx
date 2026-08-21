// Enters the code shown by the actor's authenticator app.
//
// The Turnstile challenge runs invisibly and writes its token into the hidden field the form
// submits, as the stealth ERB partial did; the server still validates that token and rejects the
// submission when it is missing. The form is a document POST, exactly as the ERB form was.
import Button from "@/components/ui/Button";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

import type { VerificationFormBase, VerificationLink } from "./types";
import VerificationFormFields from "./VerificationFormFields";

export type TotpEntryForm = VerificationFormBase & {
  code_label: string;
  code_placeholder: string;
};

export type TotpEntryTurnstile = {
  site_key: string;
  mode: "render" | "execute";
  action: string | null;
  cdata: string | null;
};

export type TotpEntryProps = {
  title: string;
  heading: string;
  description: string;
  totp_help: string;
  errors: string[];
  form: TotpEntryForm;
  turnstile: TotpEntryTurnstile;
  back: VerificationLink;
};

export default function TotpEntry({
  heading,
  description,
  totp_help: totpHelp,
  errors,
  form,
  turnstile,
  back,
}: TotpEntryProps) {
  return (
    <Page
      title={heading}
      description={description}
      up={back}
      width="narrow"
    >
      <p className="text-sm text-fg-muted">{totpHelp}</p>

      <ErrorList errors={errors} />

      <form
        action={form.action}
        method="post"
        className="flex flex-col gap-4"
      >
        <VerificationFormFields
          csrf_token={form.csrf_token}
          scope={form.scope}
          pt={form.pt}
        />
        <TextField
          label={form.code_label}
          name="verification[code]"
          inputMode="numeric"
          placeholder={form.code_placeholder}
        />

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
        />

        <Button type="submit">{form.submit_label}</Button>
      </form>
    </Page>
  );
}
