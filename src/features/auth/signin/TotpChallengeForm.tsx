// The second-factor screen for a time-based one-time code.
//
// The Turnstile challenge runs invisibly here, as the stealth partial did, so the actor is not asked
// to solve anything on top of the code. Whether the code is valid, replayed, or exhausted is decided
// by the server, which re-renders this page with the resulting messages.
import { useForm } from "@inertiajs/react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { readString } from "@/lib/payload";

import type { SignInLink, SignInTurnstile } from "./types";

export type TotpChallengeField = {
  scope: string;
  field: string;
  name: string;
  label: string;
  placeholder: string;
  max_length: number;
  inputmode: "numeric";
  help: string;
};

export type TotpChallengeFormProps = {
  title: string;
  description: string;
  form: {
    action: string;
    method: string;
    token_field: TotpChallengeField;
    submit_label: string;
  };
  error_heading: string;
  form_errors: string[];
  turnstile: SignInTurnstile;
  back_link: SignInLink;
};

export default function TotpChallengeForm({
  title,
  description,
  form,
  error_heading: errorHeading,
  form_errors: formErrors,
  turnstile,
  back_link: backLink,
}: TotpChallengeFormProps) {
  const field = form.token_field;
  const { data, setData, post, processing } = useForm<{
    [key: string]: string | null | Record<string, string>;
    "cf-turnstile-response": string;
  }>({
    [field.scope]: { [field.field]: "" },
    "cf-turnstile-response": "",
  });

  /* v8 ignore next -- useForm always initialises the scoped field as a string */
  const value = readString(data[field.scope], field.field) ?? "";

  return (
    <Page
      title={title}
      description={description}
      width="narrow"
    >
      <form
        onSubmit={(event) => {
          event.preventDefault();
          post(form.action);
        }}
        className="flex flex-col gap-4"
      >
        {formErrors.length > 0 ? (
          <div
            role="alert"
            className="animate-shake flex flex-col gap-1 rounded-md border border-danger bg-surface p-3"
          >
            <h2 className="text-sm font-semibold text-danger">{errorHeading}</h2>
            <ul className="flex flex-col gap-1 text-sm text-danger">
              {formErrors.map((message) => (
                <li key={message}>{message}</li>
              ))}
            </ul>
          </div>
        ) : null}

        <TextField
          label={field.label}
          description={field.help}
          name={field.name}
          value={value}
          onChange={(next) => setData(field.scope, { [field.field]: next })}
          placeholder={field.placeholder}
          maxLength={field.max_length}
          inputMode={field.inputmode}
        />

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
          onToken={(token) => setData("cf-turnstile-response", token)}
        />

        <div className="flex items-center gap-4">
          <Button
            type="submit"
            isDisabled={processing}
          >
            {form.submit_label}
          </Button>
          {/* Document visit: the challenge menu has its own guards. */}
          <a
            href={backLink.href}
            className="text-sm text-fg-muted underline-offset-4 hover:text-fg hover:underline"
          >
            {backLink.label}
          </a>
        </div>
      </form>
    </Page>
  );
}
