import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";

// Replaces `app/views/base/com/identity/privacy/erasures/new.html.erb`.

export type PrivacyErasureNewProps = {
  title: string;
  paragraphs: string[];
  form: { url: string; jurisdiction: string; submit_label: string };
};

export default function PrivacyErasureNew({ title, paragraphs, form }: PrivacyErasureNewProps) {
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      form.url,
      { jurisdiction: form.jurisdiction },
      {
        onStart: () => setProcessing(true),
        onFinish: () => setProcessing(false),
      },
    );
  };

  return (
    <section className="flex flex-col gap-6">
      <h1 className="text-2xl font-bold text-fg">{title}</h1>

      <div className="flex flex-col gap-3">
        {paragraphs.map((paragraph) => (
          <p
            key={paragraph}
            className="text-sm text-fg-muted"
          >
            {paragraph}
          </p>
        ))}
      </div>

      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        <input
          type="hidden"
          name="jurisdiction"
          value={form.jurisdiction}
          readOnly
        />
        <Button
          type="submit"
          variant="danger"
          isDisabled={processing}
          className="w-fit"
        >
          {form.submit_label}
        </Button>
      </form>
    </section>
  );
}
