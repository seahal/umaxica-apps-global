import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
// The signed-in landing of an auth surface.
//
// It is a directory of the ceremonies the surface owns. Every entry arrives resolved from the
// server: an item with a href is a link the visitor may follow, an item without one is a note about
// a ceremony that has no direct entry point.
import CredentialWarning, {
  type CredentialWarningProps,
} from "@/features/identity/CredentialWarning";

export type DashboardItem = {
  label: string;
  href: string | null;
};

export type DashboardSection = {
  heading: string;
  items: DashboardItem[];
};

export type SurfaceDashboardProps = {
  title: string;
  description: string;
  sections: DashboardSection[];
  /** Absent unless the server decided this actor should be prompted to add a credential. */
  credential_warning?: CredentialWarningProps | null;
};

export default function SurfaceDashboard({
  title,
  description,
  sections,
  credential_warning: credentialWarning = null,
}: SurfaceDashboardProps) {
  return (
    <Page
      title={title}
      description={description}
    >
      {credentialWarning ? <CredentialWarning {...credentialWarning} /> : null}

      {sections.map((section) => (
        <Card
          key={section.heading}
          heading={section.heading}
        >
          <ul className="flex flex-col gap-1">
            {section.items.map((item) => (
              <li
                key={item.label}
                className="text-sm"
              >
                {/* A document visit: these destinations are ceremonies with their own guards. */}
                {item.href ? (
                  <a
                    href={item.href}
                    className="text-fg underline-offset-4 hover:underline"
                  >
                    {item.label}
                  </a>
                ) : (
                  <span className="text-fg-muted">{item.label}</span>
                )}
              </li>
            ))}
          </ul>
        </Card>
      ))}
    </Page>
  );
}
