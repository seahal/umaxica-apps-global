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
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <h1>{title}</h1>
      <p>{description}</p>

      {credentialWarning ? <CredentialWarning {...credentialWarning} /> : null}

      {sections.map((section) => (
        <section key={section.heading}>
          <h2>{section.heading}</h2>
          <ul>
            {section.items.map((item) => (
              <li key={item.label}>
                {/* A document visit: these destinations are ceremonies with their own guards. */}
                {item.href ? <a href={item.href}>{item.label}</a> : item.label}
              </li>
            ))}
          </ul>
        </section>
      ))}
    </section>
  );
}
