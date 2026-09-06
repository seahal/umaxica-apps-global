import { router } from "@inertiajs/react";
import { useState, type SyntheticEvent } from "react";

import Button from "@/components/ui/Button";
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
  archive_reason: string | null;
  publication_state: string;
  revision_count: number;
  version_count: number;
  updated_at: string | null;
};

export type ManagementShowPublication = {
  public_id: string;
  effective_from: string;
  version_public_id: string;
  end_href: string;
};

export type ManagementShowProps = {
  title: string;
  description: string;
  index_href: string;
  edit_href: string;
  publish_href: string;
  archive_href: string;
  errors: Record<string, string>;
  publication: ManagementShowPublication | null;
  scheduled_publications: ManagementShowPublication[];
  entry: ManagementShowEntry;
};

const fieldClass = "w-full rounded-md border border-line bg-surface px-3 py-2 text-sm text-fg";

export default function ManagementShow({
  title,
  description,
  index_href,
  edit_href,
  publish_href,
  archive_href,
  errors,
  publication,
  scheduled_publications,
  entry,
}: ManagementShowProps) {
  const [effectiveFrom, setEffectiveFrom] = useState("");
  const [endReason, setEndReason] = useState("");
  const [archiveReason, setArchiveReason] = useState("");

  const archived = entry.archive_state === "archived";

  const publish = (event: SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(publish_href, { publication: { effective_from: effectiveFrom } });
  };

  const endPublication = (event: SyntheticEvent<HTMLFormElement>, href: string) => {
    event.preventDefault();
    router.delete(href, { data: { publication: { reason: endReason } } });
  };

  const archive = (event: SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(archive_href, { archive: { reason: archiveReason } });
  };

  const restore = (event: SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.delete(archive_href);
  };

  const fields: [string, string][] = [
    ["Public ID", entry.public_id],
    ["Surface", entry.surface],
    ["Audience", entry.audience],
    ["Locale", entry.locale],
    ["Canonical slug", entry.canonical_slug ?? "—"],
    ["Current revision", entry.current_revision_public_id ?? "—"],
    ["Revision sequence", entry.revision_sequence == null ? "—" : String(entry.revision_sequence)],
    ["Archive", archived ? `archived: ${entry.archive_reason ?? ""}` : entry.archive_state],
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
      {errors["base"] ? (
        <p
          role="alert"
          className="text-sm text-danger"
        >
          {errors["base"]}
        </p>
      ) : null}
      <dl className="grid grid-cols-1 gap-3 text-sm sm:grid-cols-2">
        {fields.map(([label, value]) => (
          <div key={label}>
            <dt className="text-fg-muted">{label}</dt>
            <dd className="text-fg">{value}</dd>
          </div>
        ))}
      </dl>
      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-fg">Publication</h2>
        {publication ? (
          <form
            action={publication.end_href}
            method="post"
            onSubmit={(event) => endPublication(event, publication.end_href)}
            className="flex flex-col gap-2"
          >
            <input
              type="hidden"
              name="_method"
              value="delete"
            />
            <p className="text-sm text-fg">
              Published since {publication.effective_from} from version {publication.version_public_id}.
            </p>
            <label className="flex flex-col gap-1 text-sm">
              <span>Reason for unpublishing</span>
              <input
                name="publication[reason]"
                className={fieldClass}
                value={endReason}
                onChange={(event) => setEndReason(event.target.value)}
              />
              {errors["reason"] ? (
                <span
                  role="alert"
                  className="text-danger"
                >
                  {errors["reason"]}
                </span>
              ) : null}
            </label>
            <div>
              <Button
                type="submit"
                variant="danger"
              >
                Unpublish
              </Button>
            </div>
          </form>
        ) : (
          <form
            action={publish_href}
            method="post"
            onSubmit={publish}
            className="flex flex-col gap-2"
          >
            <p className="text-sm text-fg-muted">
              This entry is not published. Publishing promotes the current revision to a version.
            </p>
            <label className="flex flex-col gap-1 text-sm">
              <span>Effective from (leave empty to publish now)</span>
              <input
                name="publication[effective_from]"
                type="datetime-local"
                className={fieldClass}
                value={effectiveFrom}
                onChange={(event) => setEffectiveFrom(event.target.value)}
              />
              {errors["effective_from"] ? (
                <span
                  role="alert"
                  className="text-danger"
                >
                  {errors["effective_from"]}
                </span>
              ) : null}
            </label>
            <div>
              <Button type="submit">Publish</Button>
            </div>
          </form>
        )}
        {scheduled_publications.length > 0 ? (
          <ul className="flex flex-col gap-2">
            {scheduled_publications.map((scheduled) => (
              <li
                key={scheduled.public_id}
                className="text-sm text-fg"
              >
                Scheduled for {scheduled.effective_from} from version {scheduled.version_public_id}.
                <form
                  action={scheduled.end_href}
                  method="post"
                  onSubmit={(event) => endPublication(event, scheduled.end_href)}
                  className="mt-1 flex gap-2"
                >
                  <input
                    type="hidden"
                    name="_method"
                    value="delete"
                  />
                  <input
                    name="publication[reason]"
                    aria-label="Reason for cancelling"
                    className={fieldClass}
                    value={endReason}
                    onChange={(event) => setEndReason(event.target.value)}
                  />
                  <Button
                    type="submit"
                    variant="secondary"
                  >
                    Cancel
                  </Button>
                </form>
              </li>
            ))}
          </ul>
        ) : null}
      </section>
      <section className="flex flex-col gap-2">
        <h2 className="text-sm font-medium text-fg">Archive</h2>
        {archived ? (
          <form
            action={archive_href}
            method="post"
            onSubmit={restore}
          >
            <input
              type="hidden"
              name="_method"
              value="delete"
            />
            <Button
              type="submit"
              variant="secondary"
            >
              Restore
            </Button>
          </form>
        ) : (
          <form
            action={archive_href}
            method="post"
            onSubmit={archive}
            className="flex flex-col gap-2"
          >
            <label className="flex flex-col gap-1 text-sm">
              <span>Reason for archiving</span>
              <input
                name="archive[reason]"
                className={fieldClass}
                value={archiveReason}
                onChange={(event) => setArchiveReason(event.target.value)}
              />
            </label>
            <div>
              <Button
                type="submit"
                variant="danger"
              >
                Archive
              </Button>
            </div>
          </form>
        )}
      </section>
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
