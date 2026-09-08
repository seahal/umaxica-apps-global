import { router } from "@inertiajs/react";
import { useState, type SyntheticEvent } from "react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";

export type ManagementNewProps = {
  title: string;
  description: string;
  index_href: string;
  errors: Record<string, string>;
  locales: string[];
  form: {
    action: string;
    method: string;
    title: string | null;
    summary: string | null;
    body: string;
    locale: string;
    slug: string | null;
  };
};

export default function ManagementNew({
  title,
  description,
  index_href,
  errors,
  locales,
  form,
}: ManagementNewProps) {
  const [titleValue, setTitleValue] = useState(form.title ?? "");
  const [summaryValue, setSummaryValue] = useState(form.summary ?? "");
  const [bodyValue, setBodyValue] = useState(form.body);
  const [localeValue, setLocaleValue] = useState(form.locale);
  const [slugValue, setSlugValue] = useState(form.slug ?? "");

  const submit = (event: SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(form.action, {
      entry: {
        title: titleValue,
        summary: summaryValue,
        body: bodyValue,
        locale: localeValue,
        slug: slugValue,
      },
    });
  };

  const fieldClass = "w-full rounded-md border border-line bg-surface px-3 py-2 text-sm text-fg";

  return (
    <Page
      title={title}
      description={description}
      width="wide"
      up={{ label: "All entries", href: index_href }}
      upVisit="inertia"
    >
      <form
        action={form.action}
        method="post"
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        <p className="text-sm text-fg-muted">
          The locale and the slug are fixed when the entry is created. A translation is a separate
          entry in this cell.
        </p>
        <label className="flex flex-col gap-1 text-sm">
          <span>Locale</span>
          <select
            name="entry[locale]"
            className={fieldClass}
            value={localeValue}
            onChange={(event) => setLocaleValue(event.target.value)}
          >
            {locales.map((locale) => (
              <option
                key={locale}
                value={locale}
              >
                {locale}
              </option>
            ))}
          </select>
          {errors["locale"] ? (
            <span
              role="alert"
              className="text-danger"
            >
              {errors["locale"]}
            </span>
          ) : null}
        </label>
        <label className="flex flex-col gap-1 text-sm">
          <span>Slug</span>
          <input
            name="entry[slug]"
            className={fieldClass}
            value={slugValue}
            onChange={(event) => setSlugValue(event.target.value)}
          />
          {errors["slug"] ? (
            <span
              role="alert"
              className="text-danger"
            >
              {errors["slug"]}
            </span>
          ) : null}
        </label>
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
        {errors["base"] ? (
          <p
            role="alert"
            className="text-sm text-danger"
          >
            {errors["base"]}
          </p>
        ) : null}
        <div className="flex gap-3">
          <Button type="submit">Create entry</Button>
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
