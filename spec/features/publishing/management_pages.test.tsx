import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

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
});
