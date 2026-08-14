// A self-service index listing. The server decides which entries exist and where each one links,
// so the component only renders what the props already resolved.
import { Link } from "@inertiajs/react";

export type EntityListEntry = {
  public_id: string;
  label: string;
  href: string;
};

export type EntityListProps = {
  title: string;
  body: string;
  empty: string;
  entries: EntityListEntry[];
};

export default function EntityList({ title, body, empty, entries }: EntityListProps) {
  // The surface Inertia layout owns the <main> landmark, so the page renders a section only.
  return (
    <section>
      <h1>{title}</h1>
      <p>{body}</p>

      {entries.length === 0 ? (
        <p>{empty}</p>
      ) : (
        <ul>
          {entries.map((entry) => (
            <li key={entry.public_id}>
              <Link href={entry.href}>{entry.label}</Link>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
