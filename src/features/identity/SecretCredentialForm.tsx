// The create and rename screens of a secret credential.
//
// The secret value field is present only when the server sent its label, which is what separates
// creation from a rename.
import { Link } from "@inertiajs/react";

import FormErrors from "@/features/identity/FormErrors";
import type { LabelledLink, TurnstileProps } from "@/features/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

export type SecretCredentialFormProps = {
  title: string;
  description: string;
  form: {
    action: string;
    scope: string;
    name: string;
    name_label: string;
    value_label?: string;
    confirm_saved_label?: string;
    submit: string;
    /** "patch" on the rename screen; absent for creation, which is a plain POST. */
    method?: string;
  };
  cancel_link: LabelledLink;
  turnstile: TurnstileProps;
  error_header: string | null;
  error_messages: string[];
};

export default function SecretCredentialForm({
  title,
  description,
  form,
  cancel_link: cancelLink,
  turnstile,
  error_header: errorHeader,
  error_messages: errorMessages,
}: SecretCredentialFormProps) {
  return (
    <section>
      <h1>{title}</h1>
      <p>{description}</p>

      <form
        action={form.action}
        method="post"
        data-turbo="false"
      >
        {form.method ? (
          <input
            type="hidden"
            name="_method"
            value={form.method}
          />
        ) : null}
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
        />

        <FormErrors
          heading={errorHeader}
          messages={errorMessages}
        />

        <div>
          <label htmlFor={`${form.scope}_name`}>{form.name_label}</label>
          <input
            type="text"
            id={`${form.scope}_name`}
            name={`${form.scope}[name]`}
            defaultValue={form.name}
          />
        </div>

        {form.value_label ? (
          <div>
            <label htmlFor={`${form.scope}_value`}>{form.value_label}</label>
            <input
              type="text"
              id={`${form.scope}_value`}
              name={`${form.scope}[value]`}
            />
          </div>
        ) : null}

        {form.confirm_saved_label ? (
          <div>
            <input
              type="checkbox"
              id="confirm_secret_credential_saved"
              name="confirm_secret_credential_saved"
              value="1"
            />
            <label htmlFor="confirm_secret_credential_saved">{form.confirm_saved_label}</label>
          </div>
        ) : null}

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
        />

        <div>
          <Link href={cancelLink.href}>{cancelLink.label}</Link>
          <input
            type="submit"
            value={form.submit}
          />
        </div>
      </form>
    </section>
  );
}
