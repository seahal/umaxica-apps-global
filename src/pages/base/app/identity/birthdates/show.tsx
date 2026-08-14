import type { IdentityLink } from "@/types/identity";

type Props = {
  title: string;
  description: string;
  change_unavailable: string;
  birthdate_label: string;
  not_set_label: string;
  birthdate: string | null;
  back_link: IdentityLink;
};

export default function BirthdateShow({
  title,
  description,
  change_unavailable: changeUnavailable,
  birthdate_label: birthdateLabel,
  not_set_label: notSetLabel,
  birthdate,
  back_link: backLink,
}: Props) {
  return (
    <section>
      <a href={backLink.href}>{backLink.label}</a>

      <h1>{title}</h1>
      <p>{description}</p>

      <dl>
        <dt>{birthdateLabel}</dt>
        <dd>{birthdate ? <span data-birthdate>{birthdate}</span> : notSetLabel}</dd>
      </dl>

      <p>{changeUnavailable}</p>
    </section>
  );
}
