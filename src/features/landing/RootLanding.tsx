// The thin public landing every surface answers with at its root.
//
// It used to be a self-contained ERB document with its own inline stylesheet, one copy per surface.
// The surfaces differ only in their heading and their sign-up destination, so both arrive as props
// and the markup is shared.
import ButtonLink from "@/components/ui/ButtonLink";

export type RootLandingLink = { label: string; href: string };

export type RootLandingProps = {
  // A root document renders the brand alone, so a surface whose landing carries no page title of
  // its own sends null and the layout falls back to that contract.
  title: string | null;
  heading: string;
  description: string;
  sign_up: RootLandingLink | null;
  // Surfaces that offer more than one destination (side settings, palm per-platform sign-up) send
  // them here; the server has already decided which ones the visitor may see.
  links?: RootLandingLink[] | null;
};

export default function RootLanding({
  heading,
  description,
  sign_up: signUp,
  links,
}: RootLandingProps) {
  const headingId = "root-landing-title";

  return (
    <section
      aria-labelledby={headingId}
      className="flex flex-col gap-10 py-8 sm:py-16"
    >
      <div className="flex w-full flex-col gap-6">
        <header className="flex flex-col gap-4">
          <h1
            id={headingId}
            className="text-4xl font-semibold tracking-tight text-balance text-fg sm:text-5xl"
          >
            {heading}
          </h1>
          <p className="max-w-prose text-lg text-pretty text-fg-muted">{description}</p>
        </header>

        {signUp || links?.length ? (
          <nav aria-label="Sign up">
            <ul className="flex flex-wrap items-center gap-4">
              {signUp ? (
                <li>
                  <ButtonLink href={signUp.href}>{signUp.label}</ButtonLink>
                </li>
              ) : null}
              {links?.map((link) => (
                <li key={link.href}>
                  <a
                    href={link.href}
                    className="text-sm text-fg-muted underline-offset-4 hover:text-fg hover:underline"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
        ) : null}
      </div>
    </section>
  );
}
