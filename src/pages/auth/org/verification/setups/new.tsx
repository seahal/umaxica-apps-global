// The screen an operator reaches when step-up is required but no method is configured yet.
export type OrgVerificationSetupProps = {
  title: string;
  description: string;
  back_link: { label: string; href: string } | null;
  methods: { key: string; label: string; href: string }[];
};

export default function OrgVerificationSetup({
  title,
  description,
  back_link: backLink,
  methods,
}: OrgVerificationSetupProps) {
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
            <a href={method.href}>{method.label}</a>
          </li>
        ))}
      </ul>
    </section>
  );
}
