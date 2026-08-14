// The thin public landing every surface answers with at its root.
//
// It used to be a self-contained ERB document with its own inline stylesheet, one copy per surface.
// The surfaces differ only in their heading and their sign-up destination, so both arrive as props
// and the markup is shared.
export type RootLandingProps = {
  title: string;
  heading: string;
  description: string;
  sign_up: { label: string; href: string } | null;
};

export default function RootLanding({ heading, description, sign_up: signUp }: RootLandingProps) {
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
      </div>
    </section>
  );
}
