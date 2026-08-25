import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import Checkbox from "@/components/ui/Checkbox";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TextLink from "@/components/ui/TextLink";
import type { IdentityLink } from "@/types/identity";

type SecretForm = {
  action: string;
  name_label: string;
  name: string;
  enabled_label: string;
  submit_label: string;
};

type Props = {
  title: string;
  description: string;
  back_link: IdentityLink;
  cancel_link: IdentityLink;
  form: SecretForm;
  raw_secret_credential: string;
  raw_secret_label: string;
  one_time_notice: string;
  errors: string[];
};

export default function SecretNew({
  title,
  description,
  back_link: backLink,
  cancel_link: cancelLink,
  form,
  raw_secret_credential: rawSecretCredential,
  raw_secret_label: rawSecretLabel,
  one_time_notice: oneTimeNotice,
  errors,
}: Props) {
  const [name, setName] = useState(form.name);
  const [enabled, setEnabled] = useState(false);
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      form.action,
      { user_secret_credential: { name, enabled: enabled ? "1" : "0" } },
      {
        onStart: () => setProcessing(true),

        onFinish: () => setProcessing(false),
      },
    );
  };

  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <ErrorList errors={errors} />

      <Card>
        <form
          onSubmit={submit}
          className="flex flex-col gap-4"
        >
          <TextField
            id="user_secret_credential_name"
            label={form.name_label}
            type="text"
            value={name}
            onChange={setName}
          />

          <Checkbox
            id="user_secret_credential_enabled"
            isSelected={enabled}
            onChange={setEnabled}
          >
            {form.enabled_label}
          </Checkbox>

          {/*
            Shown once and never again, so it is set apart from the fields around it rather than
            reading as one more value on the form.
          */}
          <div className="flex flex-col gap-1 rounded-lg border border-accent bg-surface-muted p-4">
            <p className="text-xs font-semibold tracking-wide text-fg-muted uppercase">
              {rawSecretLabel}
            </p>
            <p
              data-raw-secret
              className="font-mono text-sm break-all text-fg"
            >
              {rawSecretCredential}
            </p>
            <p className="text-xs text-fg-muted">{oneTimeNotice}</p>
          </div>

          <Button
            type="submit"
            isDisabled={processing}
          >
            {form.submit_label}
          </Button>
        </form>
      </Card>

      <p className="text-sm">
        <TextLink
          href={cancelLink.href}
          tone="muted"
          inertia
        >
          {cancelLink.label}
        </TextLink>
      </p>
    </Page>
  );
}
