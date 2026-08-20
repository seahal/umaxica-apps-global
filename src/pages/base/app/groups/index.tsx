type GroupsPageProps = {
  title?: string;
};

export default function GroupsIndex({ title = "Groups" }: GroupsPageProps) {
  // The base/app Inertia layout owns the <main> landmark, so the page renders a section only.
  return (
    <section className="mx-auto flex w-full max-w-4xl flex-col justify-center gap-6 p-6">
      <div className="space-y-2">
        <p className="text-xs font-semibold uppercase tracking-widest">Base App</p>
        <h1 className="text-4xl font-bold tracking-tight">{title}</h1>
      </div>

      <p className="max-w-prose text-base leading-7">groups</p>
    </section>
  );
}
