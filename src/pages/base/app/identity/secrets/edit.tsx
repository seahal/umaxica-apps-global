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

type SecretEditForm = {
  action: string;
  name_label: string;
  name: string;
  enabled_label: string;
  enabled: boolean;
  submit_label: string;
};

type Props = {
  title: string;
  description: string;
  back_link: IdentityLink;
  cancel_link: IdentityLink;
  form: SecretEditForm;
  errors: string[];
};

export default function SecretEdit({
  title,
  description,
  back_link: backLink,
  cancel_link: cancelLink,
  form,
  errors,
}: Props) {
  const [name, setName] = useState(form.name);
  const [enabled, setEnabled] = useState(form.enabled);
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(
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
