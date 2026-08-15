import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import type {
  IdentityDestructiveAction,
  IdentityLink,
  IdentityPreferenceField,
} from "@/types/identity";

type EmailEditForm = {
  action: string;
  submit_label: string;
  locked: boolean;
  always_on_label: string;
  always_on_description: string;
  promotional: IdentityPreferenceField;
  notifiable: IdentityPreferenceField;
};

type Props = {
  title: string;
  address: string;
  form: EmailEditForm;
  delete: IdentityDestructiveAction;
  cancel_link: IdentityLink;
  error: string | null;
};

export default function EmailEdit({
  title,
  address,
  form,
  delete: destroy,
  cancel_link: cancelLink,
  error,
}: Props) {
  const [promotional, setPromotional] = useState(form.promotional.checked);
  const [notifiable, setNotifiable] = useState(form.notifiable.checked);
  const [processing, setProcessing] = useState(false);
  const { confirm, dialog } = useConfirm();

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(form.action, {
      data: {
        user_email: {
          promotional: promotional ? "1" : "0",
          notifiable: notifiable ? "1" : "0",
        },
      },
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
    });
  };

  const remove = () => {
    confirm(
      { message: destroy.confirm, confirmLabel: destroy.label, cancelLabel: cancelLink.label },
      () => router.delete(destroy.url),
    );
  };

  return (
    <section>
      <h1>{title}</h1>
      <p>{address}</p>

      {error ? <p role="alert">{error}</p> : null}

      <form onSubmit={submit}>
        <div>
          <span>{form.always_on_label}</span>
          <p>{form.always_on_description}</p>
        </div>

        <div>
          <input
            id="user_email_promotional"
            type="checkbox"
            disabled={form.locked}
            checked={promotional}
            onChange={(event) => setPromotional(event.target.checked)}
          />
          <label htmlFor="user_email_promotional">{form.promotional.label}</label>
          <p>{form.promotional.description}</p>
        </div>

        <div>
          <input
            id="user_email_notifiable"
            type="checkbox"
            disabled={form.locked}
            checked={notifiable}
            onChange={(event) => setNotifiable(event.target.checked)}
          />
          <label htmlFor="user_email_notifiable">{form.notifiable.label}</label>
          <p>{form.notifiable.description}</p>
        </div>

        <button
          type="submit"
          disabled={processing}
        >
          {form.submit_label}
        </button>
      </form>

      <button
        type="button"
        onClick={remove}
      >
        {destroy.label}
      </button>

      <Link href={cancelLink.href}>{cancelLink.label}</Link>
      {dialog}
    </section>
  );
}
