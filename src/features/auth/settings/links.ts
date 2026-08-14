// A link the server already resolved: a finished label and a finished URL.
//
// A link the actor may not follow is absent from the props rather than present and hidden here.
export type SettingsLink = {
  label: string;
  href: string;
};

/** The Turnstile widget configuration `TurnstilePageProps` serializes. */
export type SettingsTurnstile = {
  site_key: string;
  mode: "render" | "execute";
  action: string | null;
  cdata: string | null;
};
