// The validation summary an identity form shows. The messages arrive fully translated.
export type FormErrorsProps = {
  heading?: string | null;
  messages: string[];
};

export default function FormErrors({ heading = null, messages }: FormErrorsProps) {
  if (messages.length === 0) {
    return null;
  }

  return (
    <div role="alert">
      {heading ? <h3>{heading}</h3> : null}
      <ul>
        {messages.map((message) => (
          <li key={message}>{message}</li>
        ))}
      </ul>
    </div>
  );
}
