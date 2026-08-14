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
import { Link } from "@inertiajs/react";

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
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-8 p-6">
      <div>
        <a href={upLink.href}>{upLink.label}</a>
      </div>

      <div className="space-y-2">
        <h1 className="text-3xl font-bold tracking-tight">{title}</h1>
        <p className="max-w-prose text-base leading-7">{description}</p>
      </div>

      <ul className="flex flex-col gap-2">
        {screens.map((screen) => (
          <li key={screen.key}>
            <Link href={screen.href}>{screen.label}</Link>
          </li>
        ))}
      </ul>
    </section>
  );
}
