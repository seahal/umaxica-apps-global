import Page from "@/components/ui/Page";
import type { PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/sessions/show.html.erb`.

export type SessionShowProps = {
  title: string;
  back_link: PageLink;
  items: { term: string; description: string }[];
};

export default function SessionShow({ title, back_link: backLink, items }: SessionShowProps) {
  return (
    <Page
      title={title}
      up={backLink}
      upVisit="inertia"
    >
      <dl className="flex flex-col gap-3 rounded-lg border border-line bg-surface p-4 text-sm">
        {items.map((item) => (
          <div
            key={item.term}
            className="flex flex-col gap-1 sm:flex-row sm:gap-2"
          >
            <dt className="font-medium text-fg-muted sm:w-48">{item.term}</dt>
            <dd className="text-fg">{item.description}</dd>
          </div>
        ))}
      </dl>
    </Page>
  );
}
