// Renames one registered passkey.
//
// Validation failures come back as an Inertia redirect carrying the errors hash, so the field reads
// its message from `errors` rather than from a re-rendered 422 body.
import { useForm } from "@inertiajs/react";

import type { TurnstileConfiguration } from "@/features/auth/settings/PasskeyDeleteButton";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { readString } from "@/lib/payload";

export type PasskeyEditProps = {
  title: string;
  action: string;
  field_label: string;
  description: string;
  submit_label: string;
  cancel_link: { label: string; href: string };
  turnstile: TurnstileConfiguration;
};

export default function PasskeyEdit({
  title,
  action,
  field_label: fieldLabel,
  description,
  submit_label: submitLabel,
  cancel_link: cancelLink,
  turnstile,
}: PasskeyEditProps) {
  // The parameter stays wrapped in `visitor_passkey`, which is the scope the controller permits.
  const form = useForm({
    visitor_passkey: { description: description },
    "cf-turnstile-response": "",
  });
  const error = readString(form.errors, "description");

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.patch(action);
  };

  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <h1>{title}</h1>

      <form onSubmit={submit}>
        {error ? (
          <div>
            <ul>
              <li role="alert">{error}</li>
            </ul>
          </div>
        ) : null}

        <div>
          <label htmlFor="visitor_passkey_description">{fieldLabel}</label>
          <input
            type="text"
            id="visitor_passkey_description"
            name="visitor_passkey[description]"
            maxLength={100}
            value={form.data.visitor_passkey.description}
            onChange={(event) =>
              form.setData("visitor_passkey", { description: event.target.value })
            }
          />
        </div>

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
          onToken={(token) => form.setData("cf-turnstile-response", token)}
        />

        <div>
          <button
            type="submit"
            disabled={form.processing}
          >
            {submitLabel}
          </button>
          <a href={cancelLink.href}>{cancelLink.label}</a>
        </div>
      </form>
    </section>
  );
}
