import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
// Redeeming an operator invitation code.
//
// A document POST so the visible Turnstile token travels in the form body; a rejected code comes
// back as this page re-rendered at 422 with the failure inline, never as a flash.
import { csrfToken } from "@/lib/csrf";

type TurnstileConfiguration = {
  site_key: string;
  mode: "render" | "execute";
  action: string | null;
  cdata: string | null;
};

export type OrgInvitationPageProps = {
  title: string;
  description: string;
  form_error: string | null;
  form_action: string;
  invitation_code_label: string;
  invitation_code: string;
  submit_label: string;
  back_link: { label: string; href: string };
  turnstile: TurnstileConfiguration;
};

export default function OrgInvitationPage({
  title,
  description,
  form_error: formError,
  form_action: formAction,
  invitation_code_label: invitationCodeLabel,
  invitation_code: invitationCode,
  submit_label: submitLabel,
  back_link: backLink,
  turnstile,
}: OrgInvitationPageProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <h1>{title}</h1>
      <p>{description}</p>

      {formError ? <p role="alert">{formError}</p> : null}

      <form
        action={formAction}
        method="post"
      >
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
          readOnly
        />

        <div>
          <label htmlFor="invitation_code">{invitationCodeLabel}</label>
          <input
            type="text"
            id="invitation_code"
            name="invitation_code"
            defaultValue={invitationCode}
            required
          />
        </div>

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
        />

        <input
          type="submit"
          value={submitLabel}
        />
      </form>

      <p>
        <a href={backLink.href}>{backLink.label}</a>
      </p>
    </section>
  );
}
