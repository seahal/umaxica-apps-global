import { Link } from "@inertiajs/react";

import type { PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/secret_credentials/show.html.erb`. The timestamps arrive
// already localised.

export type SecretCredentialShowProps = {
  title: string;
  name: string;
  created_term: string;
  created_at: string;
  last_used_term: string;
  last_used_at: string;
  back_link: PageLink;
  edit_link: PageLink;
};

const LINK = "text-sm text-fg-muted underline-offset-4 hover:text-fg hover:underline";

export default function SecretCredentialShow({
  title,
  name,
  created_term: createdTerm,
  created_at: createdAt,
  last_used_term: lastUsedTerm,
  last_used_at: lastUsedAt,
  back_link: backLink,
  edit_link: editLink,
}: SecretCredentialShowProps) {
  return (
    <section className="flex flex-col gap-6">
      <header className="flex flex-col gap-1">
        <h1 className="text-2xl font-bold text-fg">{title}</h1>
        <h3 className="text-lg font-semibold text-fg">{name}</h3>
      </header>

      <dl className="flex flex-col gap-3 rounded-lg border border-line bg-surface p-4 text-sm">
        <div className="flex flex-col gap-1 sm:flex-row sm:gap-2">
          <dt className="font-medium text-fg-muted sm:w-48">{createdTerm}</dt>
          <dd className="text-fg">{createdAt}</dd>
        </div>
        <div className="flex flex-col gap-1 sm:flex-row sm:gap-2">
          <dt className="font-medium text-fg-muted sm:w-48">{lastUsedTerm}</dt>
          <dd className="text-fg">{lastUsedAt}</dd>
        </div>
      </dl>

      <div className="flex gap-4">
        <Link
          href={backLink.href}
          className={LINK}
        >
          {backLink.label}
        </Link>
        <Link
          href={editLink.href}
          className={LINK}
        >
          {editLink.label}
        </Link>
      </div>
    </section>
  );
}
