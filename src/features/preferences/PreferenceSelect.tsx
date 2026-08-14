import { Link, router, usePage } from "@inertiajs/react";
import { useState } from "react";

import PreferenceScreenFrame, {
  type PreferenceLink,
} from "@/features/preferences/PreferenceScreenFrame";

// Backs both `option` (region, timezone, language, theme) and `selectable` (currency, calendar,
// clock, motion, density, pagination). The two shared ERB templates they replace differed only in
// how the server built the choice labels, which is still where that difference lives.

type PreferenceChoice = {
  label: string;
  value: number;
};

type PreferenceSelectForm = {
  action: string;
  method: string;
  /** Rails parameter wrapper, e.g. `preference_region`. */
  scope: string;
  /** Attribute inside the wrapper, e.g. `option_id`. */
  field: string;
  label: string;
  value: number;
  choices: PreferenceChoice[];
  submit_label: string;
  submitting_label: string;
};

type PreferenceLinkedScreen = PreferenceLink & {
  key: string;
};

export type PreferenceSelectProps = {
  screen: string;
  title: string;
  description: string;
  back_link: PreferenceLink;
  form: PreferenceSelectForm;
  region_link: PreferenceLink | null;
  linked_screens: PreferenceLinkedScreen[];
};

export default function PreferenceSelect({
  screen,
  title,
  description,
  back_link: backLink,
  form,
  region_link: regionLink,
  linked_screens: linkedScreens,
}: PreferenceSelectProps) {
  const [value, setValue] = useState(String(form.value));
  const [processing, setProcessing] = useState(false);
  const { errors } = usePage().props;
  const error = errors?.[form.field];
  const fieldId = `${form.scope}_${form.field}`;

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(
      form.action,
      { [form.scope]: { [form.field]: value } },
      {
        onStart: () => setProcessing(true),
        onFinish: () => setProcessing(false),
      },
    );
  };

  return (
    <PreferenceScreenFrame
      title={title}
      description={description}
      back_link={backLink}
    >
      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        <div>
          <label htmlFor={fieldId}>{form.label}</label>
          <div>
            <select
              id={fieldId}
              name={`${form.scope}[${form.field}]`}
              value={value}
              onChange={(event) => setValue(event.target.value)}
            >
              {form.choices.map((choice) => (
                <option
                  key={choice.value}
                  value={String(choice.value)}
                >
                  {choice.label}
                </option>
              ))}
            </select>
          </div>
          {error ? <p role="alert">{error}</p> : null}
        </div>

        <div className="flex items-center gap-4">
          <button
            type="submit"
            disabled={processing}
          >
            {processing ? form.submitting_label : form.submit_label}
          </button>
          {regionLink ? <Link href={regionLink.href}>{regionLink.label}</Link> : null}
        </div>
      </form>

      {screen === "region" && linkedScreens.length > 0 ? (
        <ul className="flex flex-col gap-2">
          {linkedScreens.map((linked) => (
            <li key={linked.key}>
              <Link href={linked.href}>{linked.label}</Link>
            </li>
          ))}
        </ul>
      ) : null}
    </PreferenceScreenFrame>
  );
}
