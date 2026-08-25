// Redeeming an operator invitation code.
//
// A document POST so the visible Turnstile token travels in the form body; a rejected code comes
// back as this page re-rendered at 422 with the failure inline, never as a flash.
import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
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
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <ErrorList errors={formError === null ? [] : [formError]} />

      <Card>
        <form
          action={formAction}
          method="post"
          className="flex flex-col gap-4"
        >
          <input
            type="hidden"
            name="authenticity_token"
            value={csrfToken()}
            readOnly
          />

          <TextField
            label={invitationCodeLabel}
            type="text"
            name="invitation_code"
            defaultValue={invitationCode}
            isRequired
          />

          <TurnstileWidget
            site_key={turnstile.site_key}
            mode={turnstile.mode}
            action={turnstile.action}
            cdata={turnstile.cdata}
          />

          <Button type="submit">{submitLabel}</Button>
        </form>
      </Card>
    </Page>
  );
}
