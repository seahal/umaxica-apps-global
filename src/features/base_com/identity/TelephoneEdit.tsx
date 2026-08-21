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
    <section className="flex flex-col gap-6">
      <h1 className="text-2xl font-bold text-fg">{title}</h1>

      <p className="rounded-lg border border-line bg-surface p-4 text-sm font-medium text-fg">
        {number}
      </p>

      <div className="flex flex-wrap items-center gap-3">
        <DestructiveButton action={destroy} />
        <Link
          href={cancelLink.href}
          className="text-sm text-fg-muted underline-offset-4 hover:text-fg hover:underline"
        >
          {cancelLink.label}
        </Link>
      </div>
    </section>
  );
}
