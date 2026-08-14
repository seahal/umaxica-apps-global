import { Link } from "@inertiajs/react";

import type { IdentityLink } from "@/types/identity";

type Props = {
  title: string;
  description: string;
  name: string;
  created_at_label: string;
  created_at: string;
  last_used_at_label: string;
  last_used_at: string;
  back_link: IdentityLink;
  edit_link: IdentityLink;
};

export default function SecretShow({
  title,
  description,
  name,
  created_at_label: createdAtLabel,
  created_at: createdAt,
  last_used_at_label: lastUsedAtLabel,
  last_used_at: lastUsedAt,
  back_link: backLink,
  edit_link: editLink,
}: Props) {
  return (
    <section>
      <h1>{title}</h1>
      <p>{description}</p>

      <h2>{name}</h2>

      <dl>
        <dt>{createdAtLabel}</dt>
        <dd>{createdAt}</dd>
        <dt>{lastUsedAtLabel}</dt>
        <dd>{lastUsedAt}</dd>
      </dl>

      <Link href={backLink.href}>{backLink.label}</Link>
      <Link href={editLink.href}>{editLink.label}</Link>
    </section>
  );
}
