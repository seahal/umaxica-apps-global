import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import GroupsIndex from "@/pages/base/app/groups/index";

describe("base app groups page", () => {
  it("renders the visible groups screen and title", () => {
    const html = renderToStaticMarkup(<GroupsIndex title="Groups" />);

    expect(html).toContain("<h1");
    expect(html).toContain("Groups");
    expect(html).toContain("groups");
  });
});
