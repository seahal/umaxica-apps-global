// The one data table.
//
// Eighteen tables were in the application under four different treatments, eight of them with no
// classes at all, so the same list of sessions looked like a different product depending on which
// surface the visitor reached it from.
//
// The cell rules are written as descendant variants rather than passed down through a column
// configuration on purpose: the caller keeps writing `<thead>`, `<th scope="col">` and `<td>`, so
// the document stays a real table — with the header association assistive technology needs — and
// nothing here has to grow a prop every time a cell wants different content.
//
// The wrapper scrolls rather than the page. A table is the one thing on these screens that cannot
// reflow to a phone: `docs/design.md` caps the column for reading, and a session list with five
// columns is wider than that cap at every mobile width.
import type { ReactNode } from "react";

const TABLE =
  "w-full border-collapse text-left text-sm " +
  "[&_thead]:bg-surface-muted " +
  "[&_th]:px-3 [&_th]:py-2 [&_th]:text-xs [&_th]:font-semibold [&_th]:tracking-wide " +
  "[&_th]:text-fg-muted [&_th]:uppercase " +
  "[&_td]:px-3 [&_td]:py-2 [&_td]:align-top [&_td]:text-fg " +
  "[&_tbody_tr]:border-t [&_tbody_tr]:border-line";

export type TableProps = {
  /** Names the table for assistive technology when the surrounding heading does not. */
  label?: string;
  children: ReactNode;
};

export default function Table({ label, children }: TableProps) {
  return (
    <div className="overflow-x-auto rounded-xl border border-line bg-surface">
      <table
        {...(label === undefined ? {} : { "aria-label": label })}
        className={TABLE}
      >
        {children}
      </table>
    </div>
  );
}
