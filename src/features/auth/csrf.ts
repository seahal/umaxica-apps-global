// The Rails CSRF token, read from the `csrf-token` meta tag the surface layout already renders.
//
// It is deliberately not a prop: a token has no business travelling through the Inertia page
// object, and the meta tag is the same source the Stimulus controllers and `form_with` used.
export function csrfToken(): string {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? "";
}
