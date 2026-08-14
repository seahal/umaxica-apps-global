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
    <section>
      <h1>{title}</h1>
      <h3>{name}</h3>
      <dl>
        <div>
          <dt>{createdTerm}</dt>
          <dd>{createdAt}</dd>
        </div>
        <div>
          <dt>{lastUsedTerm}</dt>
          <dd>{lastUsedAt}</dd>
        </div>
      </dl>
      <div>
        <Link href={backLink.href}>{backLink.label}</Link>
        <Link href={editLink.href}>{editLink.label}</Link>
      </div>
    </section>
  );
}
