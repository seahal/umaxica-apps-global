import { router } from "@inertiajs/react";
import { useState } from "react";

type Props = {
  title: string;
  notices: string[];
  form: { action: string; jurisdiction: string; submit_label: string };
};

export default function PrivacyErasureNew({ title, notices, form }: Props) {
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      form.action,
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

      {notices.map((notice) => (
        <p key={notice}>{notice}</p>
      ))}

      <form onSubmit={submit}>
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
