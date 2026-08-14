// React port of the `sign_up_birthdate_fields` helper.
//
// The part order and the separator follow the visitor's date-format preference, which the server
// resolves and sends; the browser never re-derives it. Today's date is a typing convenience only —
// it is never eligible, and the server rejects it on both the checkpoint policy and the model.
export type BirthdatePart = {
  part: string;
  label: string;
  placeholder: string;
  value: string;
  min: number;
  max: number;
};

export type BirthdateFieldsetProps = {
  format: string;
  separator: string;
  labelledby: string;
  parts: BirthdatePart[];
};

export default function BirthdateFieldset({
  format,
  separator,
  labelledby,
  parts,
}: BirthdateFieldsetProps) {
  return (
    <div
      role="group"
      aria-labelledby={labelledby}
      data-birthdate-format={format}
    >
      {parts.map((part, index) => (
        <span key={part.part}>
          {index > 0 ? separator : null}
          <label htmlFor={`birthdate_${part.part}`}>
            {part.label}{" "}
            <input
              type="number"
              id={`birthdate_${part.part}`}
              name={`birthdate_${part.part}`}
              defaultValue={part.value}
              required
              autoComplete={`bday-${part.part}`}
              inputMode="numeric"
              min={part.min}
              max={part.max}
              placeholder={part.placeholder}
              data-birthdate-part={part.part}
            />
          </label>
        </span>
      ))}
    </div>
  );
}
