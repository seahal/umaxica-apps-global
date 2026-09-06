import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";

export type ManagementIndexEntry = {
  public_id: string;
  title: string | null;
  locale: string;
  canonical_slug: string | null;
  archive_state: string;
  publication_state: string;
  revision_sequence: number | null;
  updated_at: string | null;
  show_href: string;
  edit_href: string;
};

export type ManagementIndexProps = {
  title: string;
  description: string;
  surface: string;
  audience: string;
  entries: ManagementIndexEntry[];
};

export default function ManagementIndex({ title, description, entries }: ManagementIndexProps) {
  return (
    <Page
      title={title}
      description={description}
      width="wide"
    >
      {entries.length === 0 ? (
        <p className="text-sm text-fg-muted">No entries in this cell.</p>
      ) : (
        <table className="w-full border-collapse text-left text-sm">
          <thead>
            <tr className="border-b border-line text-fg-muted">
              <th className="py-2 pr-3 font-medium">Title</th>
              <th className="py-2 pr-3 font-medium">Slug</th>
              <th className="py-2 pr-3 font-medium">Locale</th>
              <th className="py-2 pr-3 font-medium">Publication</th>
              <th className="py-2 pr-3 font-medium">Revision</th>
              <th className="py-2 pr-3 font-medium">Updated</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((entry) => (
              <tr
                key={entry.public_id}
                className="border-b border-line"
              >
                <td className="py-2 pr-3">
                  <TextLink
                    href={entry.show_href}
                    inertia
                  >
                    {entry.title ?? entry.public_id}
                  </TextLink>
                </td>
                <td className="py-2 pr-3">{entry.canonical_slug ?? "—"}</td>
                <td className="py-2 pr-3">{entry.locale}</td>
                <td className="py-2 pr-3">
                  {entry.publication_state}
                  {entry.archive_state === "archived" ? " / archived" : ""}
                </td>
                <td className="py-2 pr-3">{entry.revision_sequence ?? "—"}</td>
                <td className="py-2 pr-3">{entry.updated_at ?? "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Page>
  );
}
