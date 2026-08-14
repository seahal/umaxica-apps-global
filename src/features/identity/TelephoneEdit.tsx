// The single-telephone screen, whose only action is deletion.
import { Link } from "@inertiajs/react";

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
  return (
    <section>
      <h1>{title}</h1>
      <p>{number}</p>

      <form
        action={destroy.href}
        method="post"
        data-turbo="false"
        onSubmit={(event) => {
          if (!window.confirm(destroy.confirm)) {
            event.preventDefault();
          }
        }}
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
    </section>
  );
}
