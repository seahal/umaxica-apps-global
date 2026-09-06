import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";

export type ManagementShowEntry = {
  public_id: string;
  surface: string;
  audience: string;
  locale: string;
  canonical_slug: string | null;
  current_revision_public_id: string | null;
  revision_sequence: number | null;
  title: string | null;
  summary: string | null;
  body: unknown;
  archive_state: string;
  publication_state: string;
  revision_count: number;
  version_count: number;
  updated_at: string | null;
};

export type ManagementShowProps = {
  title: string;
  description: string;
  index_href: string;
  edit_href: string;
  entry: ManagementShowEntry;
};

export default function ManagementShow({
  title,
  description,
  index_href,
  edit_href,
  entry,
}: ManagementShowProps) {
  const fields: [string, string][] = [
    ["Public ID", entry.public_id],
    ["Surface", entry.surface],
    ["Audience", entry.audience],
    ["Locale", entry.locale],
    ["Canonical slug", entry.canonical_slug ?? "—"],
    ["Current revision", entry.current_revision_public_id ?? "—"],
    ["Revision sequence", entry.revision_sequence == null ? "—" : String(entry.revision_sequence)],
    ["Archive", entry.archive_state],
    ["Publication", entry.publication_state],
    ["Revisions", String(entry.revision_count)],
    ["Versions", String(entry.version_count)],
    ["Updated", entry.updated_at ?? "—"],
  ];

  return (
    <Page
      title={title}
      description={description}
      width="wide"
      up={{ label: "All entries", href: index_href }}
      upVisit="inertia"
      actions={
        <ButtonLink
          href={edit_href}
          inertia
        >
          Edit
        </ButtonLink>
      }
    >
      <dl className="grid grid-cols-1 gap-3 text-sm sm:grid-cols-2">
        {fields.map(([label, value]) => (
          <div key={label}>
            <dt className="text-fg-muted">{label}</dt>
            <dd className="text-fg">{value}</dd>
          </div>
        ))}
      </dl>
      {entry.summary ? (
        <section className="flex flex-col gap-1">
          <h2 className="text-sm font-medium text-fg">Summary</h2>
          <p className="text-sm text-fg">{entry.summary}</p>
        </section>
      ) : null}
      <section className="flex flex-col gap-1">
        <h2 className="text-sm font-medium text-fg">Body</h2>
        <pre className="overflow-x-auto rounded-md border border-line bg-surface-muted p-3 text-xs text-fg">
          {JSON.stringify(entry.body, null, 2)}
        </pre>
      </section>
    </Page>
  );
}
