// A bordered surface panel, with the section heading it usually carries.
//
// `rounded-lg border border-line bg-surface p-4` was written out in forty places, drifting a little
// each time — `p-2`, `px-4 py-3`, `bg-surface-muted`, sometimes with `text-sm` folded in. One
// component removes the drift and gives the heading a single treatment.
import type { ReactNode } from "react";

export type CardTone = "default" | "muted";

const TONES: Record<CardTone, string> = {
  default: "bg-surface",
  muted: "bg-surface-muted",
};

export type CardProps = {
  /** Rendered as the panel's `<h2>`. A card without one is a plain container. */
  heading?: string;
  /** Controls belonging to the panel, rendered opposite the heading. */
  actions?: ReactNode;
  tone?: CardTone;
  className?: string;
  children: ReactNode;
};

export default function Card({
  heading,
  actions,
  tone = "default",
  className,
  children,
}: CardProps) {
  return (
    <section
      className={["flex flex-col gap-4 rounded-xl border border-line p-5", TONES[tone], className]
        .filter(Boolean)
        .join(" ")}
    >
      {heading || actions ? (
        <div className="flex flex-wrap items-center justify-between gap-x-4 gap-y-2">
          {heading ? (
            <h2 className="text-sm font-semibold tracking-wide text-fg-muted uppercase">
              {heading}
            </h2>
          ) : null}

          {actions ? <div className="flex shrink-0 items-center gap-2">{actions}</div> : null}
        </div>
      ) : null}

      {children}
    </section>
  );
}
