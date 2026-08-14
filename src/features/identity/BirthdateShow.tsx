// The read-only birthdate screen. The date is already formatted by the server, and `birthdate` is
// null when none is recorded rather than the client deciding what "unset" looks like.
import { Link } from "@inertiajs/react";

export type BirthdateShowProps = {
  title: string;
  description: string;
  birthdate_label: string;
  birthdate: string | null;
  not_set: string;
  change_unavailable: string;
  back_link: { label: string; href: string };
};

export default function BirthdateShow({
  title,
  description,
  birthdate_label: birthdateLabel,
  birthdate,
  not_set: notSet,
  change_unavailable: changeUnavailable,
  back_link: backLink,
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
