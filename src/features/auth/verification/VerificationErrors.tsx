// The verification failure messages the ERB rendered with `to_sentence`. They arrive translated,
// and they describe the outcome only: no code, no token and no destination is ever among them.
export type VerificationErrorsProps = {
  errors: string[];
};

export default function VerificationErrors({ errors }: VerificationErrorsProps) {
  if (errors.length === 0) {
    return null;
  }

  return (
    <div
      role="alert"
      data-test-id="verification-errors"
    >
      {errors.join(", ")}
    </div>
  );
}
