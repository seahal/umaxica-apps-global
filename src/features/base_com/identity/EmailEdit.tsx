import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Checkbox from "@/components/ui/Checkbox";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import DestructiveButton from "@/features/base_com/identity/DestructiveButton";
import type { ConfirmedAction, PageLink, TurnstileProps } from "@/features/base_com/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

// Replaces `app/views/base/com/identity/emails/edit.html.erb`.

type Toggle = { label: string; description: string; checked: boolean };

export type EmailEditProps = {
  title: string;
  address: string;
  errors: string[];
  always_on: { label: string; description: string };
  promotional: Toggle;
  notifiable: Toggle;
  form: { url: string; scope: string; submit_label: string };
  destroy: ConfirmedAction;
  cancel_link: PageLink;
  turnstile: TurnstileProps;
};

export default function EmailEdit({
  title,
  address,
  errors,
  always_on: alwaysOn,
  promotional,
  notifiable,
  form,
  destroy,
  cancel_link: cancelLink,
  turnstile,
}: EmailEditProps) {
  const [promotionalChecked, setPromotionalChecked] = useState(promotional.checked);
  const [notifiableChecked, setNotifiableChecked] = useState(notifiable.checked);
  const [token, setToken] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(
      form.url,
      {
        [form.scope]: {
          promotional: promotionalChecked ? "1" : "0",
          notifiable: notifiableChecked ? "1" : "0",
        },
        "cf-turnstile-response": token,
      },
      {
        onStart: () => setProcessing(true),
        onFinish: () => setProcessing(false),
      },
    );
  };

  return (
    <Page
      title={title}
      description={address}
    >
      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        <ErrorList errors={errors} />

        <div className="rounded-md border border-line bg-surface-muted p-3">
          <p className="text-sm font-medium text-fg">{alwaysOn.label}</p>
          <p className="text-xs text-fg-muted">{alwaysOn.description}</p>
        </div>

        <div className="flex flex-col gap-1">
          <Checkbox
            id={`${form.scope}_promotional`}
            name={`${form.scope}[promotional]`}
            isSelected={promotionalChecked}
            onChange={setPromotionalChecked}
          >
            {promotional.label}
          </Checkbox>
          <p className="pl-6 text-xs text-fg-muted">{promotional.description}</p>
        </div>

        <div className="flex flex-col gap-1">
          <Checkbox
            id={`${form.scope}_notifiable`}
            name={`${form.scope}[notifiable]`}
            isSelected={notifiableChecked}
            onChange={setNotifiableChecked}
          >
            {notifiable.label}
          </Checkbox>
          <p className="pl-6 text-xs text-fg-muted">{notifiable.description}</p>
        </div>

        <TurnstileWidget
          {...turnstile}
          onToken={setToken}
        />

        <Button
          type="submit"
          isDisabled={processing}
          className="w-fit"
        >
          {form.submit_label}
        </Button>
      </form>

      <div className="flex items-center gap-4 border-t border-line pt-4">
        <DestructiveButton action={destroy} />
        <Link
          href={cancelLink.href}
          className="text-sm text-fg-muted underline-offset-4 hover:text-fg hover:underline"
        >
          {cancelLink.label}
        </Link>
      </div>
    </Page>
  );
}
