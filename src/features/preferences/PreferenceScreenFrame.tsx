import type { ReactNode } from "react";

import Page from "@/components/ui/Page";

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
    <Page
      title={title}
      description={description}
      up={backLink}
      upVisit="inertia"
    >
      {children}
    </Page>
  );
}
