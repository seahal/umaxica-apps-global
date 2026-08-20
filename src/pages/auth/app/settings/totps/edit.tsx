// Renames or removes one registered authenticator app.
//
// Removal keeps its confirmation and its DELETE verb; whether it is allowed at all is decided by
// the server, which refuses to leave an account without a way in.
import { router, useForm } from "@inertiajs/react";

import { useConfirm } from "@/components/ConfirmDialog";
import type { SettingsLink } from "@/features/auth/settings/links";

type Props = {
  title: string;
  description: string;
  back_link: SettingsLink;
  form: {
    action: string;
    scope: string;
    title_label: string;
    title_placeholder: string;
    title_hint: string;
    title: string | null;
    submit_label: string;
  };
  cancel_link: SettingsLink;
  destroy: { action: string; submit_label: string; confirm_message: string };
  error_header: string | null;
  error_messages: string[];
};

export default function TotpsEdit({
  title,
  description,
  back_link: backLink,
  form: formProps,
  cancel_link: cancelLink,
  destroy,
  error_header: errorHeader,
  error_messages: errorMessages,
}: Props) {
  const form = useForm({ title: formProps.title ?? "" });
  const { confirm, dialog } = useConfirm();

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.transform((data) => ({ [formProps.scope]: data }));
    form.patch(formProps.action);
  };

  const remove = () => {
    confirm(
      {
        message: destroy.confirm_message,
        confirmLabel: destroy.submit_label,
        cancelLabel: cancelLink.label,
      },
      () => router.delete(destroy.action),
    );
  };

  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <a href={backLink.href}>{backLink.label}</a>

      <div>
        <h3>{title}</h3>
        <p>{description}</p>
      </div>

      {errorHeader ? (
        <div role="alert">
          <h3>{errorHeader}</h3>
          <ul>
            {errorMessages.map((message) => (
              <li key={message}>{message}</li>
            ))}
          </ul>
        </div>
      ) : null}

      <form onSubmit={submit}>
        <label htmlFor="totp-title">{formProps.title_label}</label>
        <input
          type="text"
          id="totp-title"
          maxLength={32}
          placeholder={formProps.title_placeholder}
          value={form.data.title}
          onChange={(event) => form.setData("title", event.target.value)}
        />
        <p>{formProps.title_hint}</p>

        <a href={cancelLink.href}>{cancelLink.label}</a>
        <input
          type="submit"
          value={formProps.submit_label}
          disabled={form.processing}
        />
      </form>

      <button
        type="button"
        onClick={remove}
      >
        {destroy.submit_label}
      </button>
      {dialog}
    </section>
  );
}
