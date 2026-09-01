import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
}));

const { default: ActivityIndex } = await import("@/features/identity/ActivityIndex");

const columns = {
  occurred_at: "Occurred",
  event: "Event",
  ip_address: "IP",
  device: "Device",
  login_method: "Login method",
  context: "Context",
};

describe("ActivityIndex", () => {
  it("renders one row per activity the server sent", () => {
    const markup = renderToStaticMarkup(
      <ActivityIndex
        title="Activity"
        description="Recent events."
        back_link={{ label: "Back", href: "/identity" }}
        empty_message="No activity."
        columns={columns}
        activities={[
          {
            id: "evt-1",
            occurred_at: "1 January 2026",
            event_label: "Signed in",
            event_id: "12",
            ip_address: "203.0.113.4",
            device: "Firefox",
            login_method: "passkey",
            context: "{}",
          },
        ]}
      />,
    );

    expect(markup).toContain("Signed in");
    expect(markup).toContain("203.0.113.4");
    expect(markup).not.toContain("No activity.");
  });

  it("shows the empty message when there are no activities", () => {
    const markup = renderToStaticMarkup(
      <ActivityIndex
        title="Activity"
        description="Recent events."
        back_link={{ label: "Back", href: "/identity" }}
        empty_message="No activity."
        columns={columns}
        activities={[]}
      />,
    );

    expect(markup).toContain("No activity.");
    expect(markup).not.toContain("<table");
  });
});
