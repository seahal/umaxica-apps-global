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
    <div role="alert">
      {header ? <h3>{header}</h3> : null}
      <ul role="list">
        {errors.map((message) => (
          <li key={message}>{message}</li>
        ))}
      </ul>
    </div>
  );
}
