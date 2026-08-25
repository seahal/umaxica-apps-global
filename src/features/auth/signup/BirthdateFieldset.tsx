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
    <fieldset
      aria-labelledby={labelledby}
      data-birthdate-format={format}
      className="flex flex-wrap items-end gap-2"
    >
      {parts.map((part, index) => (
        <span
          key={part.part}
          className="flex items-end gap-2"
        >
          {index > 0 ? <span className="pb-2 text-fg-muted">{separator}</span> : null}
          <label
            htmlFor={`birthdate_${part.part}`}
            className="flex flex-col gap-1 text-sm font-medium text-fg"
          >
            {part.label}
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
              className="w-20 rounded-md border border-line bg-surface px-3 py-2 text-sm text-fg
                placeholder:text-fg-muted"
            />
          </label>
        </span>
      ))}
    </fieldset>
  );
}
