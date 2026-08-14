import { Link } from "@inertiajs/react";

import type { PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/telephones/index.html.erb`.

export type TelephoneRow = {
  public_id: string;
  number: string;
  status_label: string;
  edit_link: PageLink;
};

export type TelephonesIndexProps = {
  title: string;
  back_link: PageLink;
  new_link: PageLink;
  columns: { number: string; status: string; actions: string };
  empty_message: string;
  telephones: TelephoneRow[];
};

export default function TelephonesIndex({
  title,
  back_link: backLink,
  new_link: newLink,
  columns,
  empty_message: emptyMessage,
  telephones,
}: TelephonesIndexProps) {
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
            <th scope="col">{columns.number}</th>
            <th scope="col">{columns.status}</th>
            <th scope="col">
              <span>{columns.actions}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          {telephones.map((telephone) => (
            <tr key={telephone.public_id}>
              <td>{telephone.number}</td>
              <td>
                <span>{telephone.status_label}</span>
              </td>
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
