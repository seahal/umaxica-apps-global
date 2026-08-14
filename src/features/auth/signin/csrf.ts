// The Rails CSRF token, read from the `csrf-token` meta tag the surface Inertia shell renders.
//
// It is read from the document rather than carried as a prop so the token never travels through the
// Inertia page object. The forms that need it are native document POSTs (a provider hand-off, a
// step-up assertion), which Rails verifies exactly as it verified the ERB forms.
export function csrfToken(): string {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? "";
}
