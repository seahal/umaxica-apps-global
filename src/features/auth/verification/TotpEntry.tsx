// Enters the code shown by the actor's authenticator app.
//
// The Turnstile challenge runs invisibly and writes its token into the hidden field the form
// submits, as the stealth ERB partial did; the server still validates that token and rejects the
// submission when it is missing. The form is a document POST, exactly as the ERB form was.
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

import type { VerificationFormBase, VerificationLink } from "./types";
import VerificationErrors from "./VerificationErrors";
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
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <h1>{heading}</h1>
      <p>{description}</p>
      <p>{totpHelp}</p>

      <VerificationErrors errors={errors} />

      <form
        action={form.action}
        method="post"
      >
        <VerificationFormFields
          csrf_token={form.csrf_token}
          scope={form.scope}
          pt={form.pt}
        />
        <div>
          <label htmlFor="verification_code">{form.code_label}</label>
          <input
            type="text"
            id="verification_code"
            name="verification[code]"
            inputMode="numeric"
            placeholder={form.code_placeholder}
          />
        </div>

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
        />

        <div>
          <input
            type="submit"
            value={form.submit_label}
          />
        </div>
      </form>

      <div>
        <a href={back.href}>{back.label}</a>
      </div>
    </section>
  );
}
