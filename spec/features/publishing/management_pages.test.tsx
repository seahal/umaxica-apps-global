import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const patch = vi.fn();

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: {
    patch: (...args: unknown[]) => {
      patch(...args);
    },
  },
}));

const { default: ManagementIndex } = await import("@/features/publishing/ManagementIndex");
const { default: ManagementShow } = await import("@/features/publishing/ManagementShow");
const { default: ManagementEdit } = await import("@/features/publishing/ManagementEdit");

describe("publishing management pages", () => {
  it("renders index rows and show links", () => {
    const html = renderToStaticMarkup(
      <ManagementIndex
        title="Publishing docs/app"
        description="Entries for docs/app across locales."
        surface="docs"
        audience="app"
        entries={[
          {
            public_id: "pubidabcdefghijklmnop",
            title: "Guide",
            locale: "ja",
            canonical_slug: "guide",
            archive_state: "active",
            publication_state: "draft",
            revision_sequence: 1,
            updated_at: "2026-09-04T00:00:00Z",
            show_href: "/publishing/docs/app/entries/pubidabcdefghijklmnop",
            edit_href: "/publishing/docs/app/entries/pubidabcdefghijklmnop/edit",
          },
        ]}
      />,
    );

    expect(html).toContain("Guide");
    expect(html).toContain("guide");
    expect(html).toContain("ja");
    expect(html).toContain("/publishing/docs/app/entries/pubidabcdefghijklmnop");
  });

  it("renders show content and edit navigation", () => {
    const html = renderToStaticMarkup(
      <ManagementShow
        title="Guide"
        description="docs/app"
        index_href="/publishing/docs/app/entries"
        edit_href="/publishing/docs/app/entries/pubidabcdefghijklmnop/edit"
        entry={{
          public_id: "pubidabcdefghijklmnop",
          surface: "docs",
          audience: "app",
          locale: "ja",
          canonical_slug: "guide",
          current_revision_public_id: "revidabcdefghijklmnop",
          revision_sequence: 1,
          title: "Guide",
          summary: "Guide summary",
          body: { text: "Guide body" },
          archive_state: "active",
          publication_state: "draft",
          revision_count: 1,
          version_count: 0,
          updated_at: "2026-09-04T00:00:00Z",
        }}
      />,
    );

    expect(html).toContain("Guide summary");
    expect(html).toContain("Guide body");
    expect(html).toContain("/publishing/docs/app/entries/pubidabcdefghijklmnop/edit");
    expect(html).toContain("Edit");
  });

  it("renders current edit values and validation errors", () => {
    const html = renderToStaticMarkup(
      <ManagementEdit
        title="Edit Guide"
        description="docs/app"
        index_href="/publishing/docs/app/entries"
        show_href="/publishing/docs/app/entries/pubidabcdefghijklmnop"
        errors={{ body: "must be valid JSON", title: "can't be blank" }}
        form={{
          action: "/publishing/docs/app/entries/pubidabcdefghijklmnop",
          method: "patch",
          title: "Guide",
          summary: "Guide summary",
          body: '{\n  "text": "Guide body"\n}',
          lock_version: 0,
          locale: "ja",
          canonical_slug: "guide",
        }}
      />,
    );

    expect(html).toContain("Guide");
    expect(html).toContain("Guide summary");
    expect(html).toContain("Guide body");
    expect(html).toContain("must be valid JSON");
    expect(html).toContain("can&#x27;t be blank");
    expect(html).toContain('action="/publishing/docs/app/entries/pubidabcdefghijklmnop"');
    expect(html).toContain('name="_method"');
    expect(html).toContain("patch");
  });

  // Every optional field is null and the cell is archived: the row still has to name the entry and
  // say so, because a staff member reading the list has nothing else to identify it by.
  it("falls back to the public id and an em dash when a row has no revision yet", () => {
    const html = renderToStaticMarkup(
      <ManagementIndex
        title="Publishing docs/app"
        description="Entries for docs/app across locales."
        surface="docs"
        audience="app"
        entries={[
          {
            public_id: "pubidabcdefghijklmnop",
            title: null,
            locale: "ja",
            canonical_slug: null,
            archive_state: "archived",
            publication_state: "draft",
            revision_sequence: null,
            updated_at: null,
            show_href: "/publishing/docs/app/entries/pubidabcdefghijklmnop",
            edit_href: "/publishing/docs/app/entries/pubidabcdefghijklmnop/edit",
          },
        ]}
      />,
    );

    expect(html).toContain("pubidabcdefghijklmnop");
    expect(html).toContain("draft / archived");
    expect(html.split("—")).toHaveLength(4);
  });

  it("says the cell is empty rather than rendering a headed table with no rows", () => {
    const html = renderToStaticMarkup(
      <ManagementIndex
        title="Publishing docs/app"
        description="Entries for docs/app across locales."
        surface="docs"
        audience="app"
        entries={[]}
      />,
    );

    expect(html).toContain("No entries in this cell.");
    expect(html).not.toContain("<table");
  });

  it("shows an em dash for each unset field and omits the summary section entirely", () => {
    const html = renderToStaticMarkup(
      <ManagementShow
        title="pubidabcdefghijklmnop"
        description="docs/app"
        index_href="/publishing/docs/app/entries"
        edit_href="/publishing/docs/app/entries/pubidabcdefghijklmnop/edit"
        entry={{
          public_id: "pubidabcdefghijklmnop",
          surface: "docs",
          audience: "app",
          locale: "ja",
          canonical_slug: null,
          current_revision_public_id: null,
          revision_sequence: null,
          title: null,
          summary: null,
          body: {},
          archive_state: "active",
          publication_state: "draft",
          revision_count: 0,
          version_count: 0,
          updated_at: null,
        }}
      />,
    );

    expect(html.split("—")).toHaveLength(5);
    expect(html).not.toContain("Summary");
    expect(html).toContain("Body");
  });
});

describe("ManagementEdit", () => {
  const form = {
    action: "/publishing/docs/app/entries/pubidabcdefghijklmnop",
    method: "patch",
    title: "Guide",
    summary: "Guide summary",
    body: '{\n  "text": "Guide body"\n}',
    lock_version: 3,
    locale: "ja",
    canonical_slug: "guide",
  };

  const renderEdit = (overrides: Partial<Parameters<typeof ManagementEdit>[0]> = {}) =>
    render(
      <ManagementEdit
        title="Edit Guide"
        description="docs/app"
        index_href="/publishing/docs/app/entries"
        show_href="/publishing/docs/app/entries/pubidabcdefghijklmnop"
        errors={{}}
        form={form}
        {...overrides}
      />,
    );

  beforeEach(() => {
    patch.mockClear();
  });

  // The form posts through Inertia, not the browser, so the request the server sees is whatever
  // this handler builds. It has to carry the edited values and the lock_version the page was
  // rendered with -- that version is the whole of the concurrent-edit check on the server.
  it("submits the edited values with the lock_version the page was rendered with", async () => {
    const user = userEvent.setup();
    renderEdit();

    await user.clear(screen.getByRole("textbox", { name: "Title" }));
    await user.type(screen.getByRole("textbox", { name: "Title" }), "Guide v2");
    await user.clear(screen.getByRole("textbox", { name: "Summary" }));
    await user.type(screen.getByRole("textbox", { name: "Summary" }), "Second summary");
    await user.clear(screen.getByRole("textbox", { name: "Body (JSON)" }));
    await user.type(screen.getByRole("textbox", { name: "Body (JSON)" }), '{{"text":"v2"}');
    await user.click(screen.getByRole("button", { name: "Save revision" }));

    expect(patch).toHaveBeenCalledTimes(1);
    expect(patch).toHaveBeenCalledWith(form.action, {
      entry: {
        title: "Guide v2",
        summary: "Second summary",
        body: '{"text":"v2"}',
        lock_version: 3,
      },
    });
  });

  it("renders a stale lock_version and a base failure as alerts", () => {
    renderEdit({ errors: { lock_version: "is stale", base: "entry has no current revision" } });

    const alerts = screen.getAllByRole("alert").map((node) => node.textContent);

    expect(alerts).toContain("is stale");
    expect(alerts).toContain("entry has no current revision");
  });

  it("renders no alert when there is nothing wrong with the submission", () => {
    renderEdit();

    expect(screen.queryAllByRole("alert")).toHaveLength(0);
  });

  // A revision that was never given a title or summary still has to open in the editor, with empty
  // fields rather than the string "null", and with the slug line reduced to the locale.
  it("opens an untitled revision with empty fields and no slug suffix", () => {
    renderEdit({ form: { ...form, title: null, summary: null, canonical_slug: null } });

    expect(screen.getByRole<HTMLInputElement>("textbox", { name: "Title" }).value).toBe("");
    expect(screen.getByRole<HTMLTextAreaElement>("textbox", { name: "Summary" }).value).toBe("");
    expect(screen.getByText("Locale ja").textContent).toBe("Locale ja");
  });
});
