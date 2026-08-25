// The hidden fields every step-up form submits: the Rails CSRF token, and the scope and pt that
// carry the ceremony context across the request. `scope` and `pt` are rendered even when empty
// because the ERB forms did, and the server reads their absence and their emptiness alike.
export type VerificationFormFieldsProps = {
  csrf_token: string;
  scope: string | null;
  pt: string | null;
  /** Rails reads a non-POST verb from this field on a document submission. */
  method?: "patch" | "put" | "delete";
};

export default function VerificationFormFields({
  csrf_token: csrfToken,
  scope,
  pt,
  method,
}: VerificationFormFieldsProps) {
  return (
    <>
      {method ? (
        <input
          type="hidden"
          name="_method"
          value={method}
          readOnly
        />
      ) : null}
      <input
        type="hidden"
        name="authenticity_token"
        value={csrfToken}
        readOnly
      />
      <input
        type="hidden"
        name="verification[scope]"
        value={scope ?? ""}
        readOnly
      />
      <input
        type="hidden"
        name="verification[pt]"
        value={pt ?? ""}
        readOnly
      />
    </>
  );
}
