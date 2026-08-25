// Prop shapes the base/com identity pages share.
//
// These live beside the base/com components rather than in `src/features/identity`, which other
// surfaces own: the two families describe the same screens but reached the props boundary with
// different shapes, and merging them belongs to a pass that can see every surface at once.

export type PageLink = {
  label: string;
  href: string;
};

/** A destructive action the server decided the actor may perform. */
export type ConfirmedAction = {
  label: string;
  url: string;
  confirm: string;
};

export type TurnstileProps = {
  site_key: string;
  mode: "render" | "execute";
  action: string | null;
  cdata: string | null;
};
