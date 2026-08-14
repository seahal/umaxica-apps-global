import { Link } from "@inertiajs/react";

import type { PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/sessions/show.html.erb`.

export type SessionShowProps = {
  title: string;
  back_link: PageLink;
  items: { term: string; description: string }[];
};

export default function SessionShow({ title, back_link: backLink, items }: SessionShowProps) {
  return (
    <section>
      <h1>{title}</h1>
      <Link href={backLink.href}>{backLink.label}</Link>

      <dl>
        {items.map((item) => (
          <div key={item.term}>
            <dt>{item.term}</dt>
            <dd>{item.description}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
