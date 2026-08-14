import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import { ReactAriaProbe } from "@/features/react_aria_probe/ReactAriaProbe";

describe("ReactAriaProbe", () => {
  it("renders the demo title, an invalid probe field, and enabled/disabled buttons", () => {
    const html = renderToStaticMarkup(<ReactAriaProbe />);

    expect(html).toContain("React Aria probe");
    expect(html).toContain('data-react-aria-probe="true"');
    expect(html).toContain('data-invalid="true"');
    expect(html).toContain("Press me");
    expect(html).toContain("Disabled");
    expect(html).toContain('aria-disabled="true"');
  });
});
