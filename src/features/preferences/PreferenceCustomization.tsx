import { router, usePage } from "@inertiajs/react";
import { useState } from "react";

import PreferenceScreenFrame, {
  type PreferenceLink,
} from "@/features/preferences/PreferenceScreenFrame";

type PreferenceCustomizationForm = {
  action: string;
  method: string;
  field: string;
  label: string;
  value: boolean;
  submit_label: string;
  submitting_label: string;
};

export type PreferenceCustomizationProps = {
  screen: string;
  title: string;
  description: string;
  back_link: PreferenceLink;
  form: PreferenceCustomizationForm;
};

// Resetting is destructive, so the server refuses an unconfirmed request and sends the screen back
// with an error rather than trusting the disabled state of this button.
export default function PreferenceCustomization({
  title,
  description,
  back_link: backLink,
  form,
}: PreferenceCustomizationProps) {
  const [confirmed, setConfirmed] = useState(form.value);
  const [processing, setProcessing] = useState(false);
  const { errors } = usePage().props;
  const error = errors?.[form.field];

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.delete(
      form.action,
      { [form.field]: confirmed ? "1" : "" },
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
        {error ? (
          <ul>
            <li role="alert">{error}</li>
          </ul>
        ) : null}

        <div>
          <input
            id={form.field}
            name={form.field}
            type="checkbox"
            required
            checked={confirmed}
            onChange={(event) => setConfirmed(event.target.checked)}
          />
          <label htmlFor={form.field}>{form.label}</label>
        </div>

        <div>
          <button
            type="submit"
            disabled={processing}
          >
            {processing ? form.submitting_label : form.submit_label}
          </button>
        </div>
      </form>
    </PreferenceScreenFrame>
  );
}
