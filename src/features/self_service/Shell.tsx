// The React replacement for `app/views/base/shared/self_service/_shell.html.erb`.
//
// The ERB partial was the highest-fanout view in the base family: most self-service pages were a
// two-line wrapper around it. It stays one shared component here, and each surface page re-exports
// or renders it, because a surface Inertia resolver may only glob its own directory.

export type SelfServiceShellProps = {
  title: string;
  body: string;
};

export default function SelfServiceShell({ title, body }: SelfServiceShellProps) {
  // The surface Inertia layout owns the <main> landmark, so the page renders a section only.
  return (
    <section>
      <h1>{title}</h1>
      <p>{body}</p>
      <p>Signed in</p>
    </section>
  );
}
