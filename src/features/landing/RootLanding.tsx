// The thin public landing every surface answers with at its root.
//
// It used to be a self-contained ERB document with its own inline stylesheet, one copy per surface.
// The surfaces differ only in their heading and their sign-up destination, so both arrive as props
// and the markup is shared.
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
      className="mx-auto grid min-h-screen w-full max-w-2xl place-items-center p-8"
    >
      <div className="w-full">
        <h1
          id={headingId}
          className="mb-3 text-5xl font-bold leading-none tracking-normal"
        >
          {heading}
        </h1>
        <p className="text-base">{description}</p>
        {signUp ? (
          <p>
            <a href={signUp.href}>{signUp.label}</a>
          </p>
        ) : null}
        {links?.map((link) => (
          <p key={link.href}>
            <a href={link.href}>{link.label}</a>
          </p>
        ))}
      </div>
    </section>
  );
}
