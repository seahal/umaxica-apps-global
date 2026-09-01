import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Checkbox from "@/components/ui/Checkbox";
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
        <fieldset className="flex flex-col gap-2">
          {/* Strictly necessary cookies cannot be declined, so the row is read-only. */}
          <Checkbox
            isSelected
            isDisabled
          >
            {form.necessary_label}
          </Checkbox>

          {form.categories.map((category) => (
            <Checkbox
              key={category.key}
              name={`${form.scope}[${category.key}]`}
              /* v8 ignore next -- every category key is seeded from the form */
              isSelected={categories[category.key] ?? false}
              onChange={(isSelected: boolean) =>
                setCategories((current) => ({
                  ...current,
                  [category.key]: isSelected,
                }))
              }
            >
              {category.label}
            </Checkbox>
          ))}
        </fieldset>

        <div>
          <Button
            type="submit"
            isDisabled={processing}
          >
            {processing ? form.submitting_label : form.submit_label}
          </Button>
        </div>
      </form>
    </PreferenceScreenFrame>
  );
}
