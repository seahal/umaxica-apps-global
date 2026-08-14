import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import SurfaceDashboard, { type SurfaceDashboardProps } from "@/features/auth/SurfaceDashboard";
import RootLanding from "@/features/landing/RootLanding";
import AuthAppDashboardShow from "@/pages/auth/app/dashboards/show";
import AuthAppRootsIndex from "@/pages/auth/app/roots/index";

const props: SurfaceDashboardProps = {
  title: "Dashboard",
  description: "Sign app signed-in landing.",
  sections: [
    {
      heading: "Primary links",
      items: [{ label: "Root", href: "/?ri=jp" }],
    },
    {
      heading: "Ceremony links",
      items: [
        { label: "Sign-in guard", href: "/sign/in/guard?ri=jp" },
        { label: "Selector: handled by the sign-in guard sequence", href: null },
      ],
    },
  ],
};

describe("SurfaceDashboard", () => {
  it("links the destinations the server resolved", () => {
    const markup = renderToStaticMarkup(<SurfaceDashboard {...props} />);

    expect(markup).toContain("<h1>Dashboard</h1>");
    expect(markup).toContain("Sign app signed-in landing.");
    expect(markup).toContain('<a href="/?ri=jp">Root</a>');
    expect(markup).toContain('<a href="/sign/in/guard?ri=jp">Sign-in guard</a>');
  });

  it("renders an entry without a destination as plain text", () => {
    const markup = renderToStaticMarkup(<SurfaceDashboard {...props} />);

    expect(markup).toContain("<li>Selector: handled by the sign-in guard sequence</li>");
  });
});

describe("auth/app pages", () => {
  it("dashboards/show re-exports the shared dashboard", () => {
    expect(AuthAppDashboardShow).toBe(SurfaceDashboard);
  });

  it("roots/index re-exports the shared landing", () => {
    expect(AuthAppRootsIndex).toBe(RootLanding);
  });
});
