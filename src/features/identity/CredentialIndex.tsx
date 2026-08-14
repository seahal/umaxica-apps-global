// The identifier list of a self-service identity screen (email addresses, telephone numbers).
//
// Column headings, the verification wording and every destination arrive resolved from the server,
// so the table renders the payload without deciding anything about it.
import { Link } from "@inertiajs/react";

export type CredentialEntry = {
  public_id: string;
  value: string;
  status: string;
  edit_link: { label: string; href: string };
};

export type CredentialIndexProps = {
  title: string;
  back_link: { label: string; href: string };
  new_link: { label: string; href: string };
  columns: { value: string; status: string; actions: string };
  empty_message: string;
  entries: CredentialEntry[];
};

export default function CredentialIndex({
  title,
  back_link: backLink,
  new_link: newLink,
  columns,
  empty_message: emptyMessage,
  entries,
}: CredentialIndexProps) {
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
            <th scope="col">{columns.value}</th>
            <th scope="col">{columns.status}</th>
            <th scope="col">{columns.actions}</th>
          </tr>
        </thead>
        <tbody>
          {entries.map((entry) => (
            <tr key={entry.public_id}>
              <td>{entry.value}</td>
              <td>
                <span>{entry.status}</span>
              </td>
              <td>
                <Link href={entry.edit_link.href}>{entry.edit_link.label}</Link>
              </td>
            </tr>
          ))}
          {entries.length === 0 ? (
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
