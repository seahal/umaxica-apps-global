import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

// The one error treatment. Three near-identical components used to render validation failures, and
// the screen a message appeared on decided whether it was a bulleted danger panel or a comma-joined
// muted one. These cases pin the single treatment that replaced them.
const { default: ErrorList } = await import("@/components/ui/ErrorList");

describe("ErrorList", () => {
  it("renders nothing when the server reported no failure", () => {
    const { container } = render(<ErrorList errors={[]} />);

    expect(container.innerHTML).toBe("");
  });

  it("announces the failure and renders one item per message", () => {
    render(<ErrorList errors={["メールアドレスを入力してください", "確認が未完了です"]} />);

    expect(screen.getByRole("alert")).toBeTruthy();
    expect(screen.getAllByRole("listitem")).toHaveLength(2);
    expect(screen.getByText("確認が未完了です")).toBeTruthy();
  });

  it("renders the header only when the server sent one", () => {
    const { rerender } = render(<ErrorList errors={["Boom"]} />);

    expect(screen.queryByRole("heading")).toBeNull();

    rerender(
      <ErrorList
        errors={["Boom"]}
        header="The server rejected this form."
      />,
    );

    expect(screen.getByRole("heading", { name: "The server rejected this form." })).toBeTruthy();
  });
});
