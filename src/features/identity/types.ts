// Prop shapes the base identity screens share.

export type LabelledLink = {
  label: string;
  href: string;
};

export type ConfirmedAction = {
  label: string;
  href: string;
  confirm: string;
};

/** The Turnstile widget configuration a server-rendered form ships with. */
export type TurnstileProps = {
  site_key: string;
  mode: "render" | "execute";
  action: string | null;
  cdata: string | null;
};
