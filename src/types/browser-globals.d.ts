// Globals that a script attaches to `window` at runtime, which TypeScript cannot see from the
// module graph. `Window.turnstile` is declared by `src/lib/turnstile.ts`, which owns that API's
// shape.

import type { Application } from "@hotwired/stimulus";

declare global {
  interface Window {
    // `src/controllers/application.ts` publishes the Stimulus application for console debugging.
    Stimulus?: Application;
  }
}
