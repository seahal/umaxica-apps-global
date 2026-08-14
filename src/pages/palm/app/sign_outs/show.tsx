// The Palm browser logout confirmation. Rails decides the wording and whether a validated state
// value exists; this page only renders what it is given.
export type PalmSignOutShowProps = {
  title: string;
  heading: string;
  description: string;
  state: string | null;
};

export default function PalmSignOutShow({ heading, description, state }: PalmSignOutShowProps) {
  const headingId = "palm-sign-out-title";

  return (
    <section
      aria-labelledby={headingId}
      className="mx-auto grid min-h-screen w-full max-w-2xl place-items-center p-8"
    >
      <div className="w-full">
        <h1
          id={headingId}
          className="mb-3 text-5xl leading-none"
        >
          {heading}
        </h1>
        <p className="my-2">{description}</p>
        {state ? (
          <p className="my-2">
            State <code className="rounded px-1 py-0.5">{state}</code> was validated.
          </p>
        ) : null}
      </div>
    </section>
  );
}
