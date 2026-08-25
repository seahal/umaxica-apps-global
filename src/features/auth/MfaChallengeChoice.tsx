// The second-factor screen of a sign-in ceremony.
//
// Which factors the actor may use is decided on the server from the credentials they actually hold,
// so a factor the actor cannot use is absent from `methods` rather than rendered and hidden. When
// no factor is available the server sends the notice and the way back to the sign-in entry point.
import NavList from "@/components/ui/NavList";
import Page from "@/components/ui/Page";

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
    <Page
      title={title}
      description={description}
    >
      {/* Document visits: each factor ceremony has its own guards. */}
      <NavList items={methods} />

      {noMethodsNotice ? <p className="text-sm text-fg-muted">{noMethodsNotice}</p> : null}
      {backLink ? (
        <p className="text-sm text-fg-muted">
          <a
            href={backLink.href}
            className="underline-offset-4 hover:text-fg hover:underline"
          >
            {backLink.label}
          </a>
        </p>
      ) : null}
    </Page>
  );
}
