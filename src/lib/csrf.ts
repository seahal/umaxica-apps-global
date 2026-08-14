// The Rails CSRF token, read from the `csrf-token` meta tag the Inertia layout renders.
//
// A token is deliberately not a prop: it has no business travelling through the Inertia page
// object, and the meta tag is the same source `form_with` read.
export function csrfToken(): string {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? "";
}
