// A prompt to add another sign-in method, replacing
// `app/views/base/shared/identities/_apple_only_credential_warning.html.erb`.
//
// Whether the warning applies at all is a server decision: the prop is absent when the actor
// already has more than one credential, so the client never re-derives credential state. The links
// leave the surface for the auth service, so they are document navigations rather than Inertia
// visits.
export type CredentialWarningItem = {
  label: string;
  href: string;
};

export type CredentialWarningProps = {
  heading: string;
  body: string;
  items: CredentialWarningItem[];
};

export default function CredentialWarning({ heading, body, items }: CredentialWarningProps) {
  return (
    <section aria-labelledby="apple-only-credential-warning">
      <h2 id="apple-only-credential-warning">{heading}</h2>
      <p>{body}</p>
      <ul>
        {items.map((item) => (
          <li key={item.label}>
            <a href={item.href}>{item.label}</a>
          </li>
        ))}
      </ul>
    </section>
  );
}
