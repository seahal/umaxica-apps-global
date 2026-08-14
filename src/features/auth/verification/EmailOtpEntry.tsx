import type { VerificationFormBase, VerificationLink } from "./types";
// Enters the one-time code delivered by email.
//
// The code is never a prop: it exists only in the message the server sent and in what the actor
// types here. The form is a document PATCH (POST plus Rails' `_method`), exactly as the ERB form
// was, so the server can answer it with the step-up completion hand-off document.
import VerificationErrors from "./VerificationErrors";
import VerificationFormFields from "./VerificationFormFields";

export type EmailOtpEntryForm = VerificationFormBase & {
  code_label: string;
  code_placeholder: string;
};

export type EmailOtpEntryResend = {
  action: string;
  csrf_token: string;
  label: string;
};

export type EmailOtpEntryProps = {
  title: string;
  heading: string;
  description: string;
  delivery_help: string;
  errors: string[];
  form: EmailOtpEntryForm;
  resend: EmailOtpEntryResend;
  back: VerificationLink;
};

export default function EmailOtpEntry({
  heading,
  description,
  delivery_help: deliveryHelp,
  errors,
  form,
  resend,
  back,
}: EmailOtpEntryProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <h1>{heading}</h1>
      <p>{description}</p>
      <p>{deliveryHelp}</p>

      <VerificationErrors errors={errors} />

      <form
        action={form.action}
        method="post"
      >
        <VerificationFormFields
          csrf_token={form.csrf_token}
          scope={form.scope}
          pt={form.pt}
          method="patch"
        />
        <div>
          <label htmlFor="verification_code">{form.code_label}</label>
          <input
            type="text"
            id="verification_code"
            name="verification[code]"
            inputMode="numeric"
            autoComplete="one-time-code"
            placeholder={form.code_placeholder}
          />
        </div>

        <div>
          <input
            type="submit"
            value={form.submit_label}
          />
        </div>
      </form>

      <div>
        <form
          action={resend.action}
          method="post"
        >
          <input
            type="hidden"
            name="authenticity_token"
            value={resend.csrf_token}
            readOnly
          />
          <button type="submit">{resend.label}</button>
        </form>
      </div>

      <div>
        <a href={back.href}>{back.label}</a>
      </div>
    </section>
  );
}
