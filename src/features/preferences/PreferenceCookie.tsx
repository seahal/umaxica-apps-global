import { router } from "@inertiajs/react";
import { useState } from "react";

import PreferenceScreenFrame, {
  type PreferenceLink,
} from "@/features/preferences/PreferenceScreenFrame";

type PreferenceCookieCategory = {
  key: string;
  label: string;
  value: boolean;
};

type PreferenceCookieForm = {
  action: string;
  method: string;
  scope: string;
  necessary_label: string;
  categories: PreferenceCookieCategory[];
  submit_label: string;
  submitting_label: string;
};

export type PreferenceCookieProps = {
  screen: string;
  title: string;
  description: string;
  back_link: PreferenceLink;
  form: PreferenceCookieForm;
};

export default function PreferenceCookie({
  title,
  description,
  back_link: backLink,
  form,
}: PreferenceCookieProps) {
  const [categories, setCategories] = useState(() =>
    Object.fromEntries(form.categories.map((category) => [category.key, category.value])),
  );
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(
      form.action,
      { [form.scope]: categories },
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
        <div className="flex flex-col gap-2">
          {/* Strictly necessary cookies cannot be declined, so the row is read-only. */}
          <div>
            <input
              id="accept_necessary_cookies"
              type="checkbox"
              checked
              disabled
              readOnly
            />
            <label htmlFor="accept_necessary_cookies">{form.necessary_label}</label>
          </div>

          {form.categories.map((category) => {
            const inputId = `${form.scope}_${category.key}`;

            return (
              <div key={category.key}>
                <input
                  id={inputId}
                  name={`${form.scope}[${category.key}]`}
                  type="checkbox"
                  checked={categories[category.key] ?? false}
                  onChange={(event) =>
                    setCategories((current) => ({
                      ...current,
                      [category.key]: event.target.checked,
                    }))
                  }
                />
                <label htmlFor={inputId}>{category.label}</label>
              </div>
            );
          })}
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
