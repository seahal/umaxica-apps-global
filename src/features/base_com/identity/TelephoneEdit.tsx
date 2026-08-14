import { Link } from "@inertiajs/react";

import DestructiveButton from "@/features/base_com/identity/DestructiveButton";
import type { ConfirmedAction, PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/telephones/edit.html.erb`, which offers removal only.

export type TelephoneEditProps = {
  title: string;
  number: string;
  destroy: ConfirmedAction;
  cancel_link: PageLink;
};

export default function TelephoneEdit({
  title,
  number,
  destroy,
  cancel_link: cancelLink,
}: TelephoneEditProps) {
  return (
    <section>
      <h1>{title}</h1>
      <p>{number}</p>
      <DestructiveButton action={destroy} />
      <Link href={cancelLink.href}>{cancelLink.label}</Link>
    </section>
  );
}
