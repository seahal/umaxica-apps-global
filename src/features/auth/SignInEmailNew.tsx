// Start of the email sign-in ceremony: the address a one-time code is sent to.
//
// The Turnstile token travels with the submission exactly as the ERB form posted it, and the server
// still decides whether the challenge passed. A validation failure comes back as a redirect with the
// errors hash.
import { useForm } from "@inertiajs/react";

import type { TurnstileConfiguration } from "@/features/auth/settings/PasskeyDeleteButton";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { readString } from "@/lib/payload";

export type SignInEmailNewProps = {
  title: string;
  description: string;
  action: string;
  pt: string | null;
  field_label: string;
  submit_label: string;
  back_link: { label: string; href: string };
  turnstile: TurnstileConfiguration;
};

export default function SignInEmailNew({
  title,
  description,
  action,
  pt,
  field_label: fieldLabel,
  submit_label: submitLabel,
  back_link: backLink,
  turnstile,
}: SignInEmailNewProps) {
  const form = useForm({
    user_email: { address: "" },
    pt: pt ?? "",
    "cf-turnstile-response": "",
  });
  const error = readString(form.errors, "address");

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.post(action);
  };

  return (
    <section className="mx-auto flex w-full max-w-lg flex-col gap-6 p-6">
      <div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>

      <form onSubmit={submit}>
        {error ? (
          <div className="animate-shake">
            <ul>
              <li role="alert">
                <span>{error}</span>
              </li>
            </ul>
          </div>
        ) : null}

        <div>
          <label htmlFor="user_email_address">{fieldLabel}</label>
          <input
            type="email"
            id="user_email_address"
            name="user_email[address]"
            placeholder="name@example.com"
            value={form.data.user_email.address}
            onChange={(event) => form.setData("user_email", { address: event.target.value })}
            required
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
        </div>
      </form>

      <div>
        <a href={backLink.href}>
          <span>{backLink.label}</span>
        </a>
      </div>
    </section>
  );
}
