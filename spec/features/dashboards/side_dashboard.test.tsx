import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import SideDashboard, { type SideDashboardProps } from "@/features/dashboards/SideDashboard";
import SideAppDashboardsShow from "@/pages/side/app/dashboards/show";
import SideComDashboardsShow from "@/pages/side/com/dashboards/show";
import SideOrgDashboardsShow from "@/pages/side/org/dashboards/show";

const props: SideDashboardProps = {
  title: "Dashboard",
  heading: "Dashboard",
  description: "Side app signed-in landing.",
  sections: [
    {
      title: "Primary links",
      links: [
        { label: "Root", href: "/?ri=jp" },
        { label: "Sign out", href: "/sign/out/new?ri=jp" },
      ],
    },
    {
      title: "Protocol links",
      links: [{ label: "Authorize", href: "/oidc/authorization?ri=jp" }],
    },
  ],
};

describe("SideDashboard", () => {
  it("renders the heading and the description the server built", () => {
    const markup = renderToStaticMarkup(<SideDashboard {...props} />);

    expect(markup).toContain("<h1");
    expect(markup).toContain("Dashboard");
    expect(markup).toContain("Side app signed-in landing.");
  });

  it("renders every section with the links the server generated", () => {
    const markup = renderToStaticMarkup(<SideDashboard {...props} />);

    expect(markup).toContain("Primary links");
    expect(markup).toContain("Protocol links");
    expect(markup).toMatch(/<a href="\/\?ri=jp"[^>]*>Root<\/a>/u);
    expect(markup).toMatch(/<a href="\/sign\/out\/new\?ri=jp"[^>]*>Sign out<\/a>/u);
    expect(markup).toMatch(/<a href="\/oidc\/authorization\?ri=jp"[^>]*>Authorize<\/a>/u);
  });

  it("renders nothing extra when the server sends no sections", () => {
    const markup = renderToStaticMarkup(
      <SideDashboard
        {...props}
        sections={[]}
      />,
    );

    expect(markup).not.toContain("<a href");
  });
});

describe("side dashboard pages", () => {
  it.each([
    ["side/app", SideAppDashboardsShow],
    ["side/com", SideComDashboardsShow],
    ["side/org", SideOrgDashboardsShow],
  ])("%s renders the shared dashboard", (_surface, Page) => {
    expect(Page).toBe(SideDashboard);
  });
});
