// The CSRF token the surface shell published in `csrf_meta_tags`.
//
// The migrated sign-up forms submit as ordinary documents, exactly as their ERB predecessors did,
// so each one carries the token in a hidden field. Rails accepts the global token for any form,
// which is what `form_authenticity_token` put in the ERB partials.
export function csrfToken(): string {
  // The browser always has `document`; this guards SSR evaluation of the module.
  /* v8 ignore next -- jsdom always provides document */
  if (typeof document === "undefined") {
    return "";
  }

  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? "";
}
