// Preference index page, rendered by base/app, base/com, and base/org from their own page module.
//
// Every label and href arrives translated and fully qualified from Rails, because the request
// context (region, language, theme, timezone) is resolved server side by PreferenceGlobal and
// merged into every generated URL.
//
// The screen links are Inertia visits because every preference edit screen is an Inertia page. The
// up link leaves the preference tree for a server rendered page, so it stays a plain anchor: an
// Inertia visit to a non-Inertia response fails with "All Inertia requests must receive a valid
// Inertia response".
import NavList from "@/components/ui/NavList";
import Page from "@/components/ui/Page";

type PreferenceLink = {
  label: string;
  href: string;
};

type PreferenceScreen = PreferenceLink & {
  key: string;
};

export type PreferenceIndexProps = {
  title: string;
  description: string;
  up_link: PreferenceLink;
  screens: PreferenceScreen[];
};

export default function PreferenceIndex({
  title,
  description,
  up_link: upLink,
  screens,
}: PreferenceIndexProps) {
  // The surface Inertia layout owns the <main> landmark, exactly as the ERB layout does for the
  // server rendered preference screens, so the page renders a section rather than nesting one.
  return (
    <Page
      title={title}
      description={description}
      up={upLink}
    >
      <NavList
        items={screens}
        visit="inertia"
      />
    </Page>
  );
}
