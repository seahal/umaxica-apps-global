// The step-up setup screen: the actor has no usable verification method yet.
//
// Only the methods that are actually missing are offered, and the server decides which those are,
// so a method already configured is absent from `methods` rather than filtered in the browser. The
// back link exists only when the ceremony carried a destination to return to.
export type VerificationSetupLink = {
  key: string;
  label: string;
  href: string;
};

export type VerificationSetupProps = {
  title: string;
  description: string;
  back_link: VerificationSetupLink | null;
  methods: VerificationSetupLink[];
};

export default function VerificationSetup({
  title,
  description,
  back_link: backLink,
  methods,
}: VerificationSetupProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <h1>{title}</h1>
      <p>{description}</p>

      {backLink ? (
        <p>
          <a href={backLink.href}>{backLink.label}</a>
        </p>
      ) : null}

      <ul>
        {methods.map((method) => (
          <li key={method.key}>
            {/* Document visits: registration lives on the identity host for email. */}
            <a href={method.href}>{method.label}</a>
          </li>
        ))}
      </ul>
    </section>
  );
}
