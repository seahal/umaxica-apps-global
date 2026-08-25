import { Link } from "@inertiajs/react";

import Table from "@/components/ui/Table";
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

const LINK = "text-sm text-fg-muted underline-offset-4 hover:text-fg hover:underline";
const NEW_LINK =
  "inline-flex w-fit items-center rounded-md border border-line bg-surface px-3 py-1.5 " +
  "text-sm font-medium text-fg hover:bg-surface-muted";

export default function EmailsIndex({
  title,
  back_link: backLink,
  new_link: newLink,
  columns,
  empty_message: emptyMessage,
  emails,
}: EmailsIndexProps) {
  return (
    <section className="flex flex-col gap-6">
      <h1 className="text-2xl font-bold text-fg">{title}</h1>
      <Link
        href={backLink.href}
        className={LINK}
      >
        {backLink.label}
      </Link>

      <div>
        <Link
          href={newLink.href}
          className={NEW_LINK}
        >
          {newLink.label}
        </Link>
      </div>

      <Table>
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
            <tr
              key={email.public_id}
              className="last:border-0"
            >
              <td>{email.address}</td>
              <td>
                <span>{email.status_label}</span>
              </td>
              <td>
                <Link
                  href={email.edit_link.href}
                  className={LINK}
                >
                  {email.edit_link.label}
                </Link>
              </td>
            </tr>
          ))}
          {emails.length === 0 ? (
            <tr>
              <td
                colSpan={3}
                className="py-6 text-center"
              >
                <p className="text-sm text-fg-muted">{emptyMessage}</p>
              </td>
            </tr>
          ) : null}
        </tbody>
      </Table>
    </section>
  );
}
