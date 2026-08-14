// Secret-credential sign-in for operators.
//
// A document POST, as the ERB form was: the server answers with a redirect on success and with this
// page re-rendered at 422 on failure, and the visible Turnstile token has to travel in the form
// body under the field name the server verifies.
import { csrfToken } from "@/features/auth/csrf";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

type TurnstileConfiguration = {
  site_key: string;
  mode: "render" | "execute";
  action: string | null;
  cdata: string | null;
};

export type OrgSecretSignInPageProps = {
  title: string;
  form_action: string;
  hidden_fields: { pt: string | null; ri: string };
  errors_title: string;
  errors: string[];
  identifier: {
    name: string;
    label: string;
    placeholder: string;
    min_length: number;
    max_length: number;
    pattern: string;
  };
  secret: { name: string; label: string; placeholder: string };
  submit_label: string;
  back_link: { label: string; href: string };
  turnstile: TurnstileConfiguration;
};

export default function OrgSecretSignInPage({
  title,
  form_action: formAction,
  hidden_fields: hiddenFields,
  errors_title: errorsTitle,
  errors,
  identifier,
  secret,
  submit_label: submitLabel,
  back_link: backLink,
  turnstile,
}: OrgSecretSignInPageProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <div>
        <h1>{title}</h1>
      </div>

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

        {errors.length > 0 ? (
          <div role="alert">
            <h2>{errorsTitle}</h2>
            <ul>
              {errors.map((message) => (
                <li key={message}>{message}</li>
              ))}
            </ul>
          </div>
        ) : null}

        {hiddenFields.pt ? (
          <input
            type="hidden"
            name="pt"
            value={hiddenFields.pt}
            readOnly
          />
        ) : null}
        <input
          type="hidden"
          name="ri"
          value={hiddenFields.ri}
          readOnly
        />

        <div>
          <label htmlFor="secret_credential_login_form_identifier">{identifier.label}</label>
          <input
            type="text"
            id="secret_credential_login_form_identifier"
            name={identifier.name}
            placeholder={identifier.placeholder}
            autoComplete="username"
            autoCapitalize="characters"
            minLength={identifier.min_length}
            maxLength={identifier.max_length}
            pattern={identifier.pattern}
            spellCheck={false}
            required
          />
        </div>

        <div>
          <label htmlFor="secret_credential_login_form_secret_credential_value">
            {secret.label}
          </label>
          <input
            type="password"
            id="secret_credential_login_form_secret_credential_value"
            name={secret.name}
            placeholder={secret.placeholder}
            autoComplete="current-password"
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
          <a href={backLink.href}>{backLink.label}</a>
        </div>
      </form>
    </section>
  );
}
