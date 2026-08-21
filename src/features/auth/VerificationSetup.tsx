// The step-up setup screen: the actor has no usable verification method yet.
//
// Only the methods that are actually missing are offered, and the server decides which those are,
// so a method already configured is absent from `methods` rather than filtered in the browser. The
// back link exists only when the ceremony carried a destination to return to.
import NavList from "@/components/ui/NavList";
import Page from "@/components/ui/Page";

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
    <Page
      title={title}
      description={description}
    >
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

      {/* Document visits: registration lives on the identity host for email. */}
      <NavList items={methods} />
    </Page>
  );
}
