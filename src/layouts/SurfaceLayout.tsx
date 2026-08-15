// The persistent layout every Inertia page of every surface renders inside.
//
// It replaces the header and footer that the surface ERB layouts used to build, and it is
// persistent in the Inertia sense: a visit swaps the page below it without remounting the chrome,
// so the cookie banner keeps its dismissed state and the theme control keeps its selection across
// navigation. It renders nothing it decides for itself — `chrome` is a shared prop assembled by
// SurfaceChrome on the server.
import { usePage } from "@inertiajs/react";
import type { ReactNode } from "react";

import CookieBanner from "@/components/chrome/CookieBanner";
import ThemeControls from "@/components/chrome/ThemeControls";
import type { SharedProps } from "@/types/inertia";

export default function SurfaceLayout({ children }: { children: ReactNode }) {
  const { chrome } = usePage<SharedProps>().props;

  return (
    <>
      <header>
        {chrome.banner ? (
          <section aria-label="banner">
            {chrome.banner.title ? <h2>{chrome.banner.title}</h2> : null}
            <p>{chrome.banner.body}</p>
          </section>
        ) : null}

        {chrome.primary_navigation ? (
          <nav aria-label="Primary">
            <ul>
              {chrome.primary_navigation.map((link) => (
                <li key={link.href}>
                  {/* Cross-host and full-page destinations, so a document visit rather than
                      an Inertia visit. */}
                  <a href={link.href}>{link.label}</a>
                </li>
              ))}
            </ul>
          </nav>
        ) : null}

        <p>
          <strong>
            <a href={chrome.brand.href}>{chrome.brand.name}</a>
          </strong>
          {chrome.family_label ? <> {chrome.family_label}</> : null} ({chrome.surface})
        </p>
      </header>

      <main id="main">{children}</main>

      <footer>
        {chrome.footer_navigation ? (
          <nav aria-label="Footer">
            <ul>
              {chrome.footer_navigation.map((link) => (
                <li key={link.href}>
                  <a href={link.href}>{link.label}</a>
                </li>
              ))}
            </ul>
          </nav>
        ) : null}

        {chrome.cookie_controls || chrome.theme_controls ? (
          <aside aria-label="Preferences">
            {chrome.cookie_controls ? <CookieBanner controls={chrome.cookie_controls} /> : null}
            {chrome.theme_controls ? <ThemeControls controls={chrome.theme_controls} /> : null}
          </aside>
        ) : null}

        <div>
          <span className="opacity-50">{chrome.copyright}</span>
        </div>
      </footer>
    </>
  );
}
