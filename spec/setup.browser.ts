// Shared Vitest setup for the "component" project (Vitest Browser Mode, real Chromium).
//
// This project runs inside an actual browser tab, so `Element.scrollTo`, `window.matchMedia`, and
// `window.cookieStore` are the real implementations, not stand-ins. Only `spec/setup.ts` (the
// "unit"/jsdom-era setup) needs those shims; this file exists so a spec importing shared setup
// under Browser Mode does not accidentally pull in jsdom-only workarounds.
import { cleanup } from "@testing-library/react";
import { afterEach } from "vitest";

// Testing Library keeps every rendered tree in the document until it is told otherwise. React Aria
// renders overlays into a portal on `document.body`, outside the container a spec mounted, so
// without this a dialog from one test is still in the DOM while the next one queries it. This is
// real DOM cleanup, not a jsdom workaround, and applies equally in a real browser tab.
afterEach(() => {
  cleanup();
});

export const specSetup = {};
