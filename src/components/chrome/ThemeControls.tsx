// React port of the `theme` Stimulus controller.
//
// A choice applies to the document immediately and is then persisted; the stored preference is the
// authority, so the control reconciles with whatever the server answers rather than assuming the
// write succeeded.
import { useEffect, useRef, useState } from "react";

import { csrfToken } from "@/lib/request";
import {
  applyTheme,
  fetchStoredTheme,
  persistTheme,
  readThemeCookie,
  watchSystemTheme,
  type Theme,
} from "@/lib/theme";
import type { ChromeThemeControls } from "@/types/inertia";

const THEME_ORDER: Theme[] = ["system", "light", "dark"];

export default function ThemeControls({ controls }: { controls: ChromeThemeControls }) {
  const [theme, setTheme] = useState<Theme>(() =>
    typeof document === "undefined" ? "system" : readThemeCookie(),
  );
  // A choice made before the stored preference arrives wins: the visitor is more current than the
  // in-flight read.
  const chosen = useRef(false);
  const themeRef = useRef(theme);
  themeRef.current = theme;

  useEffect(() => {
    const stopWatching = watchSystemTheme(() => themeRef.current);

    void fetchStoredTheme().then((stored) => {
      if (stored && !chosen.current) {
        setTheme(stored);
        applyTheme(stored);
      }
    });

    return stopWatching;
  }, []);

  if (controls.hidden) {
    return null;
  }

  const select = (next: Theme) => {
    chosen.current = true;
    setTheme(next);
    applyTheme(next);

    void persistTheme(next, csrfToken()).then((stored) => {
      setTheme(stored);
      applyTheme(stored);
    });
  };

  return (
    <aside
      aria-labelledby="theme-title"
      className="border border-red-300 p-4 rounded"
    >
      <form>
        <fieldset className="space-y-3">
          <legend
            id="theme-title"
            className="text-sm font-semibold"
          >
            {controls.title}
          </legend>

          <p className="text-xs text-gray-600">{controls.description}</p>

          <div className="space-y-2">
            {THEME_ORDER.map((option) => (
              <label
                key={option}
                className="flex items-center gap-2 cursor-pointer"
              >
                <input
                  type="radio"
                  name="theme"
                  value={option}
                  checked={theme === option}
                  onChange={() => select(option)}
                />
                <span>{controls.options[option]}</span>
              </label>
            ))}
          </div>
        </fieldset>
      </form>
    </aside>
  );
}
