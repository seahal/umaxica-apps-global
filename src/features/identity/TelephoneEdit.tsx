// The single-telephone screen, whose only action is deletion.
import { Link } from "@inertiajs/react";

import { useConfirm } from "@/components/ConfirmDialog";
import type { ConfirmedAction, LabelledLink } from "@/features/identity/types";
import { csrfToken } from "@/lib/csrf";

export type TelephoneEditProps = {
  title: string;
  number: string;
  delete: ConfirmedAction;
  cancel_link: LabelledLink;
};

export default function TelephoneEdit({
  title,
  number,
  delete: destroy,
  cancel_link: cancelLink,
}: TelephoneEditProps) {
  const { confirm, dialog } = useConfirm();

  // The submission is held back until the actor accepts, then replayed with `submit()`, which
  // sends the same document DELETE without running this handler again.
  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    confirm(
      { message: destroy.confirm, confirmLabel: destroy.label, cancelLabel: cancelLink.label },
      () => form.submit(),
    );
  };

  return (
    <section>
      <h1>{title}</h1>
      <p>{number}</p>

      <form
        action={destroy.href}
        method="post"
        data-turbo="false"
        onSubmit={submit}
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
