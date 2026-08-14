import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import RootLanding, { type RootLandingProps } from "@/features/landing/RootLanding";
import BaseAppRootsIndex from "@/pages/base/app/roots/index";
import BaseComRootsIndex from "@/pages/base/com/roots/index";
import BaseOrgRootsIndex from "@/pages/base/org/roots/index";

const props: RootLandingProps = {
  title: "Base App",
  heading: "Base App",
  description: "This endpoint is intentionally thin.",
  sign_up: { label: "Sign up", href: "/oidc/authorization?ri=jp" },
};

describe("RootLanding", () => {
  it("labels the landing section with the heading it renders", () => {
    const markup = renderToStaticMarkup(<RootLanding {...props} />);

    expect(markup).toContain('aria-labelledby="root-landing-title"');
    expect(markup).toContain('<h1 id="root-landing-title"');
    expect(markup).toContain("Base App");
  });

  it("renders the description the server translated", () => {
    expect(renderToStaticMarkup(<RootLanding {...props} />)).toContain(
      "This endpoint is intentionally thin.",
    );
  });

  it("links to the sign-up destination the server generated", () => {
    expect(renderToStaticMarkup(<RootLanding {...props} />)).toContain(
      '<a href="/oidc/authorization?ri=jp">Sign up</a>',
    );
  });

  it("omits the sign-up link when the surface offers none", () => {
    const markup = renderToStaticMarkup(
      <RootLanding
        {...props}
        sign_up={null}
      />,
    );

    expect(markup).not.toContain("<a href");
  });
});

describe("surface root pages", () => {
  // Each surface resolves pages only from its own directory, so every surface needs its own module
  // for the shared landing.
  it.each([
    ["base/app", BaseAppRootsIndex],
    ["base/com", BaseComRootsIndex],
    ["base/org", BaseOrgRootsIndex],
  ])("%s renders the shared landing", (_surface, Page) => {
    expect(Page).toBe(RootLanding);
  });
});
