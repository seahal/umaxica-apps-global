// The validation messages the server produced, rendered as the ERB error blocks did.

export default function ErrorList({
  errors,
  header,
}: {
  errors: string[];
  // `| undefined` is explicit because callers forward an optional server prop straight through,
  // and under exactOptionalPropertyTypes a bare `header?: string` would refuse that.
  header?: string | undefined;
}) {
  if (errors.length === 0) {
    return null;
  }

  return (
    <div
      role="alert"
      className="flex flex-col gap-1 rounded-md border border-danger bg-surface p-3 text-sm text-danger"
    >
      {header ? <h3 className="font-semibold">{header}</h3> : null}
      <ul
        role="list"
        className="list-disc pl-5"
      >
        {errors.map((message) => (
          <li key={message}>{message}</li>
        ))}
      </ul>
    </div>
  );
}
