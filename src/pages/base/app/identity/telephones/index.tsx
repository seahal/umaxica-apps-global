import { Link } from "@inertiajs/react";

import type { IdentityLink } from "@/types/identity";

type TelephoneRow = {
  public_id: string;
  number: string;
  status_label: string;
  edit_link: IdentityLink;
};

type Props = {
  title: string;
  empty_message: string;
  back_link: IdentityLink;
  new_link: IdentityLink;
  table_headings: { number: string; status: string; actions: string };
  telephones: TelephoneRow[];
};

export default function TelephonesIndex({
  title,
  empty_message: emptyMessage,
  back_link: backLink,
  new_link: newLink,
  table_headings: headings,
  telephones,
}: Props) {
  return (
    <section>
      <a href={backLink.href}>{backLink.label}</a>

      <h1>{title}</h1>

      <Link href={newLink.href}>{newLink.label}</Link>

      <table>
        <thead>
          <tr>
            <th scope="col">{headings.number}</th>
            <th scope="col">{headings.status}</th>
            <th scope="col">{headings.actions}</th>
          </tr>
        </thead>
        <tbody>
          {telephones.map((telephone) => (
            <tr key={telephone.public_id}>
              <td>{telephone.number}</td>
              <td>{telephone.status_label}</td>
              <td>
                <Link href={telephone.edit_link.href}>{telephone.edit_link.label}</Link>
              </td>
            </tr>
          ))}
          {telephones.length === 0 ? (
            <tr>
              <td colSpan={3}>{emptyMessage}</td>
            </tr>
          ) : null}
        </tbody>
      </table>
    </section>
  );
}
