// The second-factor screen of a sign-in ceremony.
//
// Which factors the actor may use is decided on the server from the credentials they actually hold,
// so a factor the actor cannot use is absent from `methods` rather than rendered and hidden. When
// no factor is available the server sends the notice and the way back to the sign-in entry point.
export type MfaMethodLink = {
  key: string;
  label: string;
  href: string;
};

export type MfaChallengeChoiceProps = {
  title: string;
  description: string;
  methods: MfaMethodLink[];
  no_methods_notice: string | null;
  back_link: MfaMethodLink | null;
};

export default function MfaChallengeChoice({
  title,
  description,
  methods,
  no_methods_notice: noMethodsNotice,
  back_link: backLink,
}: MfaChallengeChoiceProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>

      <div>
        {methods.map((method) => (
          <p key={method.key}>
            {/* Document visit: the factor ceremony has its own guards. */}
            <a href={method.href}>{method.label}</a>
          </p>
        ))}
        {noMethodsNotice ? <p>{noMethodsNotice}</p> : null}
        {backLink ? (
          <p>
            <a href={backLink.href}>{backLink.label}</a>
          </p>
        ) : null}
      </div>
    </section>
  );
}
