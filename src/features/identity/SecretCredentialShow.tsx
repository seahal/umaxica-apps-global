// A single secret credential's metadata. Timestamps arrive already localised.
import { Link } from "@inertiajs/react";

import type { LabelledLink } from "@/features/identity/types";

export type SecretCredentialShowProps = {
  title: string;
  description: string;
  name: string;
  created_at_label: string;
  created_at: string;
  last_used_at_label: string;
  last_used_at: string;
  back_link: LabelledLink;
  edit_link: LabelledLink;
};

export default function SecretCredentialShow({
  title,
  description,
  name,
  created_at_label: createdAtLabel,
  created_at: createdAt,
  last_used_at_label: lastUsedAtLabel,
  last_used_at: lastUsedAt,
  back_link: backLink,
  edit_link: editLink,
}: SecretCredentialShowProps) {
  return (
    <section>
      <h1>{title}</h1>
      <p>{description}</p>

      <h2>{name}</h2>
      <dl>
        <div>
          <dt>{createdAtLabel}</dt>
          <dd>{createdAt}</dd>
        </div>
        <div>
          <dt>{lastUsedAtLabel}</dt>
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
