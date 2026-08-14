// Prop shapes shared by the step-up verification screens.
//
// Every string arrives translated and every href arrives generated: the server decides which method
// an actor may use, so a method they cannot use is absent from the payload rather than hidden here.

/** A finished navigation target. */
export type VerificationLink = {
  label: string;
  href: string;
};

/** A method entry on a choice screen. */
export type VerificationMethodLink = VerificationLink & {
  key: string;
};

/**
 * The fields every step-up form carries. The forms stay document submissions, as the ERB forms
 * were, so each one posts its own Rails CSRF token; the server answers with the completion hand-off
 * document or with the page re-rendered, never with an Inertia visit.
 */
export type VerificationFormBase = {
  action: string;
  csrf_token: string;
  scope: string | null;
  pt: string | null;
  submit_label: string;
};
