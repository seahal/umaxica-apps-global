import { Link } from "@inertiajs/react";

import type { PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/birthdates/show.html.erb`.

export type BirthdateShowProps = {
  title: string;
  description: string;
  back_link: PageLink;
  birthdate_label: string;
  birthdate: string | null;
  not_set: string;
  change_unavailable: string;
};

export default function BirthdateShow({
  title,
  description,
  back_link: backLink,
  birthdate_label: birthdateLabel,
  birthdate,
  not_set: notSet,
  change_unavailable: changeUnavailable,
}: BirthdateShowProps) {
  return (
    <section>
      <Link href={backLink.href}>{backLink.label}</Link>

      <h1>{title}</h1>
      <p>{description}</p>

      <dl>
        <dt>{birthdateLabel}</dt>
        <dd>{birthdate ? <span data-birthdate>{birthdate}</span> : notSet}</dd>
      </dl>

      <p>{changeUnavailable}</p>
    </section>
  );
}
