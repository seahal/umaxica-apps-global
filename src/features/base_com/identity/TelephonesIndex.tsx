import { Link } from "@inertiajs/react";

import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";
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

const LINK = "text-sm text-fg-muted underline-offset-4 hover:text-fg hover:underline";
export default function TelephonesIndex({
  title,
  back_link: backLink,
  new_link: newLink,
  columns,
  empty_message: emptyMessage,
  telephones,
}: TelephonesIndexProps) {
  return (
    <Page
      title={title}
      up={backLink}
      upVisit="inertia"
    >
      <div>
        <ButtonLink
          href={newLink.href}
          inertia
        >
          {newLink.label}
        </ButtonLink>
      </div>

      <Table>
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
            <tr
              key={telephone.public_id}
              className="last:border-0"
            >
              <td>{telephone.number}</td>
              <td>
                <span>{telephone.status_label}</span>
              </td>
              <td>
                <Link
                  href={telephone.edit_link.href}
                  className={LINK}
                >
                  {telephone.edit_link.label}
                </Link>
              </td>
            </tr>
          ))}
          {telephones.length === 0 ? (
            <tr>
              <td
                colSpan={3}
                className="py-6 text-center"
              >
                {emptyMessage}
              </td>
            </tr>
          ) : null}
        </tbody>
      </Table>
    </Page>
  );
}
