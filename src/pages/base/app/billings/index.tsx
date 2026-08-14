type Props = {
  title: string;
  description: string;
};

// The surface Inertia layout owns the <main> landmark, so the page renders a section only.
export default function BillingsIndex({ title, description }: Props) {
  return (
    <section>
      <h1>{title}</h1>
      <p>{description}</p>
    </section>
  );
}
