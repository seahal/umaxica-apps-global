import { Link, router } from "@inertiajs/react";

import { useConfirm } from "@/components/ConfirmDialog";
import type { IdentityDestructiveAction, IdentityLink } from "@/types/identity";

type Props = {
  title: string;
  number: string;
  delete: IdentityDestructiveAction;
  cancel_link: IdentityLink;
};

export default function TelephoneEdit({
  title,
  number,
  delete: destroy,
  cancel_link: cancelLink,
}: Props) {
  const { confirm, dialog } = useConfirm();

  const remove = () => {
    confirm(
      { message: destroy.confirm, confirmLabel: destroy.label, cancelLabel: cancelLink.label },
      () => router.delete(destroy.url),
    );
  };

  return (
    <section>
      <h1>{title}</h1>
      <p>{number}</p>

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
