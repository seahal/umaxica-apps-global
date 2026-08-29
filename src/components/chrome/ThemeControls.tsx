// React port of the `theme` Stimulus controller.
//
// A choice applies to the document immediately and is then persisted; the stored preference is the
// authority, so the control reconciles with whatever the server answers rather than assuming the
// write succeeded.
import { useEffect, useRef, useState } from "react";

import RadioGroup from "@/components/ui/RadioGroup";
import { csrfToken } from "@/lib/request";
import {
  applyTheme,
  fetchStoredTheme,
  persistTheme,
  themeFromDocument,
  watchSystemTheme,
  watchThemeCookie,
  type Theme,
} from "@/lib/theme";
import type { ChromeThemeControls } from "@/types/inertia";

const THEME_ORDER: Theme[] = ["system", "light", "dark"];

export default function ThemeControls({ controls }: { controls: ChromeThemeControls }) {
  // Rails renders `data-theme` from the same `ct` cookie the control reconciles with, and reading
  // that cookie is asynchronous now, so the document is what the first render starts from: the
  // radio shows the theme the visitor is already looking at instead of a placeholder that a
  // resolved cookie read would replace a tick later.
  const [theme, setTheme] = useState<Theme>(() =>
    typeof document === "undefined" ? "system" : themeFromDocument(),
  );
  // A choice made before the stored preference arrives wins: the visitor is more current than the
  // in-flight read.
  const chosen = useRef(false);
  const themeRef = useRef(theme);

  // The system-theme listener below outlives every render, so it reads the choice through a ref
  // rather than a captured value. Writing that ref during render would make the ref observable to
  // the render pass itself; the listener only ever reads it from an event, so an effect is early
  // enough.
  useEffect(() => {
    themeRef.current = theme;
  }, [theme]);

  useEffect(() => {
    const stopWatching = watchSystemTheme(() => themeRef.current);

    // This control lives in the persistent layout, so an Inertia visit never remounts it. The
    // theme preference screen writes the same cookie through the server, and without this the
    // radio would keep showing the theme the visitor just replaced.
    const stopFollowingCookie = watchThemeCookie(setTheme);

    const reconcile = async () => {
      const stored = await fetchStoredTheme();
      if (stored && !chosen.current) {
        setTheme(stored);
        applyTheme(stored);
      }
    };

    void reconcile();

    return () => {
      stopWatching();
      stopFollowingCookie();
    };
  }, []);

  if (controls.hidden) {
    return null;
  }

  const select = (next: Theme) => {
    chosen.current = true;
    setTheme(next);
    applyTheme(next);

    const persist = async () => {
      const stored = await persistTheme(next, csrfToken());
      setTheme(stored);
      applyTheme(stored);
    };

    void persist();
  };

  return (
    <RadioGroup
      label={controls.title}
      description={controls.description}
      value={theme}
      onChange={select}
      options={THEME_ORDER.map((option) => ({
        value: option,
        label: controls.options[option],
      }))}
    />
  );
}
