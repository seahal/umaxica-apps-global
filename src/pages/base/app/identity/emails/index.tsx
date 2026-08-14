import { Link } from "@inertiajs/react";

import type { IdentityLink } from "@/types/identity";

type EmailRow = {
  public_id: string;
  address: string;
  status_label: string;
  edit_link: IdentityLink;
};

type Props = {
  title: string;
  empty_message: string;
  back_link: IdentityLink;
  new_link: IdentityLink;
  table_headings: { address: string; status: string; actions: string };
  emails: EmailRow[];
};

export default function EmailsIndex({
  title,
  empty_message: emptyMessage,
  back_link: backLink,
  new_link: newLink,
  table_headings: headings,
  emails,
}: Props) {
  return (
    <section>
      <a href={backLink.href}>{backLink.label}</a>

      <h1>{title}</h1>

      <Link href={newLink.href}>{newLink.label}</Link>

      <table>
        <thead>
          <tr>
            <th scope="col">{headings.address}</th>
            <th scope="col">{headings.status}</th>
            <th scope="col">{headings.actions}</th>
          </tr>
        </thead>
        <tbody>
          {emails.map((email) => (
            <tr key={email.public_id}>
              <td>{email.address}</td>
              <td>{email.status_label}</td>
              <td>
                <Link href={email.edit_link.href}>{email.edit_link.label}</Link>
              </td>
            </tr>
          ))}
          {emails.length === 0 ? (
            <tr>
              <td colSpan={3}>{emptyMessage}</td>
            </tr>
          ) : null}
        </tbody>
      </table>
    </section>
  );
}
