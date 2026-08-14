import { Link } from "@inertiajs/react";

import type { PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/emails/index.html.erb`. The verified/unverified wording is
// resolved on the server, so the status column is finished text rather than a status id.

export type EmailRow = {
  public_id: string;
  address: string;
  status_label: string;
  edit_link: PageLink;
};

export type EmailsIndexProps = {
  title: string;
  back_link: PageLink;
  new_link: PageLink;
  columns: { address: string; status: string; actions: string };
  empty_message: string;
  emails: EmailRow[];
};

export default function EmailsIndex({
  title,
  back_link: backLink,
  new_link: newLink,
  columns,
  empty_message: emptyMessage,
  emails,
}: EmailsIndexProps) {
  return (
    <section>
      <h1>{title}</h1>
      <Link href={backLink.href}>{backLink.label}</Link>

      <div>
        <Link href={newLink.href}>{newLink.label}</Link>
      </div>

      <table>
        <thead>
          <tr>
            <th scope="col">{columns.address}</th>
            <th scope="col">{columns.status}</th>
            <th scope="col">
              <span>{columns.actions}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          {emails.map((email) => (
            <tr key={email.public_id}>
              <td>{email.address}</td>
              <td>
                <span>{email.status_label}</span>
              </td>
              <td>
                <Link href={email.edit_link.href}>{email.edit_link.label}</Link>
              </td>
            </tr>
          ))}
          {emails.length === 0 ? (
            <tr>
              <td colSpan={3}>
                <p>{emptyMessage}</p>
              </td>
            </tr>
          ) : null}
        </tbody>
      </table>
    </section>
  );
}
