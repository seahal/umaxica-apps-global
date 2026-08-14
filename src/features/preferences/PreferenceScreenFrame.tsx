import { Link } from "@inertiajs/react";
import type { ReactNode } from "react";

export type PreferenceLink = {
  label: string;
  href: string;
};

export type PreferenceScreenFrameProps = {
  title: string;
  description: string;
  back_link: PreferenceLink;
  children: ReactNode;
};

// Shared chrome for every preference edit screen: the back link, the heading, and the description.
// The back link targets another preference screen, all of which are Inertia pages, so it is a
// client-side visit rather than a document load.
export default function PreferenceScreenFrame({
  title,
  description,
  back_link: backLink,
  children,
}: PreferenceScreenFrameProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-8 p-6">
      <div>
        <Link href={backLink.href}>{backLink.label}</Link>
      </div>

      <div className="space-y-2">
        <h1 className="text-3xl font-bold tracking-tight">{title}</h1>
        {description ? <p className="max-w-prose text-base leading-7">{description}</p> : null}
      </div>

      {children}
    </section>
  );
}
