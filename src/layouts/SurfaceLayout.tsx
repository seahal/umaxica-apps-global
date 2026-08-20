// The persistent layout every Inertia page of every surface renders inside.
//
// It replaces the header and footer that the surface ERB layouts used to build, and it is
// persistent in the Inertia sense: a visit swaps the page below it without remounting the chrome,
// so the cookie banner keeps its dismissed state and the theme control keeps its selection across
// navigation. It renders nothing it decides for itself — `chrome` is a shared prop assembled by
// SurfaceChrome on the server.
//
// The document structure here is plain semantic HTML on purpose. Landmarks, headings and lists are
// what assistive technology navigates by, and React Aria has nothing to add to them: it is an
// interaction layer, and there is no interaction in a header.
import { usePage } from "@inertiajs/react";
import type { ReactNode } from "react";

import CookieBanner from "@/components/chrome/CookieBanner";
import ThemeControls from "@/components/chrome/ThemeControls";

const NAV_LINK = "text-sm text-fg-muted underline-offset-4 hover:text-fg hover:underline";

export default function SurfaceLayout({ children }: { children: ReactNode }) {
  const { chrome } = usePage().props;

  return (
    <div className="flex min-h-screen flex-col">
      <header className="border-b border-line bg-surface">
        {chrome.banner ? (
          <section
            aria-label="banner"
            className="border-b border-line bg-surface-muted px-4 py-2 text-sm text-fg"
          >
            <div className="mx-auto max-w-5xl">
              {chrome.banner.title ? (
                <h2 className="font-semibold">{chrome.banner.title}</h2>
              ) : null}
              <p>{chrome.banner.body}</p>
            </div>
          </section>
        ) : null}

        <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4 px-4 py-3">
          <p className="text-base font-semibold text-fg">
            <a
              href={chrome.brand.href}
              className="hover:underline"
            >
              {chrome.brand.name}
            </a>
            {chrome.family_label ? (
              <span className="ml-2 font-normal text-fg-muted">{chrome.family_label}</span>
            ) : null}
            <span className="ml-2 text-sm font-normal text-fg-muted">({chrome.surface})</span>
          </p>

          {chrome.primary_navigation ? (
            <nav aria-label="Primary">
              <ul className="flex flex-wrap items-center gap-4">
                {chrome.primary_navigation.map((link) => (
                  <li key={link.href}>
                    {/* Cross-host and full-page destinations, so a document visit rather than
                        an Inertia visit. */}
                    <a
                      href={link.href}
                      className={NAV_LINK}
                    >
                      {link.label}
                    </a>
                  </li>
                ))}
              </ul>
            </nav>
          ) : null}
        </div>
      </header>

      <main
        id="main"
        className="mx-auto w-full max-w-5xl grow px-4 py-8"
      >
        {children}
      </main>

      <footer className="border-t border-line bg-surface">
        <div className="mx-auto flex max-w-5xl flex-col gap-6 px-4 py-6">
          {chrome.footer_navigation ? (
            <nav aria-label="Footer">
              <ul className="flex flex-wrap gap-4">
                {chrome.footer_navigation.map((link) => (
                  <li key={link.href}>
                    <a
                      href={link.href}
                      className={NAV_LINK}
                    >
                      {link.label}
                    </a>
                  </li>
                ))}
              </ul>
            </nav>
          ) : null}

          {chrome.theme_controls ? (
            <aside aria-label="Preferences">
              <ThemeControls controls={chrome.theme_controls} />
            </aside>
          ) : null}

          <p className="text-xs text-fg-muted">{chrome.copyright}</p>
        </div>
      </footer>

      {/*
        Outside the footer: the banner is fixed to the viewport, so nesting it inside a
        content landmark misreports where it sits in the document.
      */}
      {chrome.cookie_controls ? <CookieBanner controls={chrome.cookie_controls} /> : null}
    </div>
  );
}
