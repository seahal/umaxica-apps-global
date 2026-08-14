// The single-session screen. It is still the scaffold the ERB template carried; the props are the
// finished strings the server sends.
export type SessionShowProps = {
  title: string;
  heading: string;
  body: string;
};

export default function SessionShow({ heading, body }: SessionShowProps) {
  return (
    <section>
      <h1>{heading}</h1>
      <p>{body}</p>
    </section>
  );
}
