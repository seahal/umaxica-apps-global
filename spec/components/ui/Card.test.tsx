import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import Card from "@/components/ui/Card";

describe("Card", () => {
  it("renders as a plain container when it carries neither a heading nor actions", () => {
    const markup = renderToStaticMarkup(<Card>body</Card>);

    expect(markup).toContain("body");
    expect(markup).not.toContain("<h2");
    expect(markup).not.toContain("justify-between");
  });

  it("renders a heading with no actions", () => {
    const markup = renderToStaticMarkup(<Card heading="Section">body</Card>);

    expect(markup).toContain("Section");
    expect(markup).not.toContain("shrink-0");
  });

  it("renders its actions beside a heading", () => {
    const markup = renderToStaticMarkup(
      <Card
        heading="Section"
        actions={<button type="button">Action</button>}
      >
        body
      </Card>,
    );

    expect(markup).toContain("Section");
    expect(markup).toContain("Action");
  });

  it("renders its actions even without a heading", () => {
    const markup = renderToStaticMarkup(
      <Card actions={<button type="button">Action</button>}>body</Card>,
    );

    expect(markup).not.toContain("<h2");
    expect(markup).toContain("Action");
  });
});
