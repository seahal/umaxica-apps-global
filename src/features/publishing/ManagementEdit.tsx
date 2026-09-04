import { router } from "@inertiajs/react";
import { useState, type SyntheticEvent } from "react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";

export type ManagementEditProps = {
  title: string;
  description: string;
  index_href: string;
  show_href: string;
  errors: Record<string, string>;
  form: {
    action: string;
    method: string;
    title: string | null;
    summary: string | null;
    body: string;
    lock_version: number;
    locale: string;
    canonical_slug: string | null;
  };
};

export default function ManagementEdit({
  title,
  description,
  index_href,
  show_href,
  errors,
  form,
}: ManagementEditProps) {
  const [titleValue, setTitleValue] = useState(form.title ?? "");
  const [summaryValue, setSummaryValue] = useState(form.summary ?? "");
  const [bodyValue, setBodyValue] = useState(form.body);

  const submit = (event: SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(form.action, {
      entry: {
        title: titleValue,
        summary: summaryValue,
        body: bodyValue,
        lock_version: form.lock_version,
      },
    });
  };

  const fieldClass = "w-full rounded-md border border-line bg-surface px-3 py-2 text-sm text-fg";

  return (
    <Page
      title={title}
      description={description}
      width="wide"
      up={{ label: "Back to entry", href: show_href }}
      upVisit="inertia"
    >
      <form
        action={form.action}
        method="post"
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        <input
          type="hidden"
          name="_method"
          value="patch"
        />
        <p className="text-sm text-fg-muted">
          Locale {form.locale}
          {form.canonical_slug ? ` · slug ${form.canonical_slug}` : ""}
        </p>
        <label className="flex flex-col gap-1 text-sm">
          <span>Title</span>
          <input
            name="entry[title]"
            className={fieldClass}
            value={titleValue}
            onChange={(event) => setTitleValue(event.target.value)}
          />
          {errors["title"] ? (
            <span
              role="alert"
              className="text-danger"
            >
              {errors["title"]}
            </span>
          ) : null}
        </label>
        <label className="flex flex-col gap-1 text-sm">
          <span>Summary</span>
          <textarea
            name="entry[summary]"
            className={fieldClass}
            rows={3}
            value={summaryValue}
            onChange={(event) => setSummaryValue(event.target.value)}
          />
          {errors["summary"] ? (
            <span
              role="alert"
              className="text-danger"
            >
              {errors["summary"]}
            </span>
          ) : null}
        </label>
        <label className="flex flex-col gap-1 text-sm">
          <span>Body (JSON)</span>
          <textarea
            name="entry[body]"
            className={`${fieldClass} font-mono text-xs`}
            rows={16}
            value={bodyValue}
            onChange={(event) => setBodyValue(event.target.value)}
          />
          {errors["body"] ? (
            <span
              role="alert"
              className="text-danger"
            >
              {errors["body"]}
            </span>
          ) : null}
        </label>
        {errors["lock_version"] ? (
          <p
            role="alert"
            className="text-sm text-danger"
          >
            {errors["lock_version"]}
          </p>
        ) : null}
        {errors["base"] ? (
          <p
            role="alert"
            className="text-sm text-danger"
          >
            {errors["base"]}
          </p>
        ) : null}
        <div className="flex gap-3">
          <Button type="submit">Save revision</Button>
          <a
            href={index_href}
            className="inline-flex items-center text-sm text-fg-muted underline-offset-4 hover:underline"
          >
            All entries
          </a>
        </div>
      </form>
    </Page>
  );
}
