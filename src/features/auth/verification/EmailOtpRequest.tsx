import type { VerificationFormBase, VerificationLink } from "./types";
// Asks the actor to have a one-time code sent to their verified address.
//
// The address itself never crosses: the server knows which one it delivers to, and the screen only
// starts the delivery. The form is a document POST, exactly as the ERB form was.
import VerificationErrors from "./VerificationErrors";
import VerificationFormFields from "./VerificationFormFields";

export type EmailOtpRequestProps = {
  title: string;
  heading: string;
  description: string;
  errors: string[];
  form: VerificationFormBase;
  back: VerificationLink;
};

export default function EmailOtpRequest({
  heading,
  description,
  errors,
  form,
  back,
}: EmailOtpRequestProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <h1>{heading}</h1>
      <p>{description}</p>

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
