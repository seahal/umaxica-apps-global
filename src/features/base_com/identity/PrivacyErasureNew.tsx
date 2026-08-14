import { router } from "@inertiajs/react";
import { useState } from "react";

// Replaces `app/views/base/com/identity/privacy/erasures/new.html.erb`.

export type PrivacyErasureNewProps = {
  title: string;
  paragraphs: string[];
  form: { url: string; jurisdiction: string; submit_label: string };
};

export default function PrivacyErasureNew({ title, paragraphs, form }: PrivacyErasureNewProps) {
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
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
    <section>
      <h1>{title}</h1>
      {paragraphs.map((paragraph) => (
        <p key={paragraph}>{paragraph}</p>
      ))}

      <form onSubmit={submit}>
        <input
          type="hidden"
          name="jurisdiction"
          value={form.jurisdiction}
          readOnly
        />
        <button
          type="submit"
          disabled={processing}
        >
          {form.submit_label}
        </button>
      </form>
    </section>
  );
}
