import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
// Renaming a registered passkey.
//
// The form is a document PATCH so the stealth Turnstile token travels in the same field the server
// verifies; the server answers a rejected update by re-rendering this page with 422 and the model's
// error messages, exactly as the ERB form did.
import { csrfToken } from "@/lib/csrf";

type TurnstileConfiguration = {
  site_key: string;
  mode: "render" | "execute";
  action: string | null;
  cdata: string | null;
};

export type OrgPasskeySettingsEditProps = {
  title: string;
  form_action: string;
  description_label: string;
  description_value: string;
  submit_label: string;
  cancel_link: { label: string; href: string };
  errors_title: string;
  errors: string[];
  turnstile: TurnstileConfiguration;
};

export default function OrgPasskeySettingsEdit({
  title,
  form_action: formAction,
  description_label: descriptionLabel,
  description_value: descriptionValue,
  submit_label: submitLabel,
  cancel_link: cancelLink,
  errors_title: errorsTitle,
  errors,
  turnstile,
}: OrgPasskeySettingsEditProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <h1>{title}</h1>

      <form
        action={formAction}
        method="post"
      >
        <input
          type="hidden"
          name="_method"
          value="patch"
          readOnly
        />
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
          readOnly
        />

        {errors.length > 0 ? (
          <div role="alert">
            <h3>{errorsTitle}</h3>
            <ul>
              {errors.map((message) => (
                <li key={message}>{message}</li>
              ))}
            </ul>
          </div>
        ) : null}

        <div>
          <label htmlFor="staff_passkey_description">{descriptionLabel}</label>
          <input
            type="text"
            id="staff_passkey_description"
            name="staff_passkey[description]"
            defaultValue={descriptionValue}
            maxLength={100}
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
            value={submitLabel}
          />
          <a href={cancelLink.href}>{cancelLink.label}</a>
        </div>
      </form>
    </section>
  );
}
