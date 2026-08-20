// The per-address email preference screen.
//
// The always-on notifications are described but not offered as a control, because the server sends
// them unconditionally; only the two preferences the operator may actually change have inputs.
import { Link } from "@inertiajs/react";

import { useConfirm } from "@/components/ConfirmDialog";
import FormErrors from "@/features/identity/FormErrors";
import type { ConfirmedAction, LabelledLink, TurnstileProps } from "@/features/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

export type EmailPreferenceEditProps = {
  title: string;
  address: string;
  form: {
    action: string;
    scope: string;
    promotional: boolean;
    notifiable: boolean;
    always_on_label: string;
    always_on_description: string;
    promotional_label: string;
    promotional_description: string;
    notifiable_label: string;
    notifiable_description: string;
    submit: string;
    turnstile: TurnstileProps;
  };
  delete: ConfirmedAction;
  cancel_link: LabelledLink;
  error_messages: string[];
};

export default function EmailPreferenceEdit({
  title,
  address,
  form,
  delete: destroy,
  cancel_link: cancelLink,
  error_messages: errorMessages,
}: EmailPreferenceEditProps) {
  const { confirm, dialog } = useConfirm();

  // The deletion is held back until the actor accepts, then replayed with `submit()`, which sends
  // the same document DELETE without running this handler again.
  const submitDeletion = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    const deletionForm = event.currentTarget;
    confirm(
      { message: destroy.confirm, confirmLabel: destroy.label, cancelLabel: cancelLink.label },
      () => deletionForm.submit(),
    );
  };

  return (
    <section>
      <h1>{title}</h1>
      <p>{address}</p>

      <form
        action={form.action}
        method="post"
        data-turbo="false"
      >
        <input
          type="hidden"
          name="_method"
          value="patch"
        />
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
        />

        <FormErrors messages={errorMessages} />

        <div>
          <p>{form.always_on_label}</p>
          <p>{form.always_on_description}</p>
        </div>

        <div>
          <input
            type="hidden"
            name={`${form.scope}[promotional]`}
            value="0"
          />
          <input
            type="checkbox"
            id={`${form.scope}_promotional`}
            name={`${form.scope}[promotional]`}
            value="1"
            defaultChecked={form.promotional}
          />
          <label htmlFor={`${form.scope}_promotional`}>{form.promotional_label}</label>
          <p>{form.promotional_description}</p>
        </div>

        <div>
          <input
            type="hidden"
            name={`${form.scope}[notifiable]`}
            value="0"
          />
          <input
            type="checkbox"
            id={`${form.scope}_notifiable`}
            name={`${form.scope}[notifiable]`}
            value="1"
            defaultChecked={form.notifiable}
          />
          <label htmlFor={`${form.scope}_notifiable`}>{form.notifiable_label}</label>
          <p>{form.notifiable_description}</p>
        </div>

        <TurnstileWidget
          site_key={form.turnstile.site_key}
          mode={form.turnstile.mode}
          action={form.turnstile.action}
          cdata={form.turnstile.cdata}
        />

        <input
          type="submit"
          value={form.submit}
        />
      </form>

      <form
        action={destroy.href}
        method="post"
        data-turbo="false"
        onSubmit={submitDeletion}
      >
        <input
          type="hidden"
          name="_method"
          value="delete"
        />
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
        />
        <input
          type="submit"
          value={destroy.label}
        />
      </form>

      <div>
        <Link href={cancelLink.href}>{cancelLink.label}</Link>
      </div>
      {dialog}
    </section>
  );
}
