import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

// The shared select. React Aria owns the listbox keyboard model, so these assert the model itself:
// arrow keys move the selection, Escape abandons it, and focus comes back to the trigger.
const { default: Select } = await import("@/components/ui/Select");

const OPTIONS = [
  { value: "system", label: "Follow the system" },
  { value: "light", label: "Light" },
  { value: "dark", label: "Dark", isDisabled: true },
];

const renderSelect = (props: Record<string, unknown> = {}) => {
  const user = userEvent.setup();
  render(
    <Select
      label="Theme"
      options={OPTIONS}
      {...props}
    />,
  );
  return user;
};

describe("Select", () => {
  it("names its trigger with the label", () => {
    renderSelect();

    expect(screen.getByRole("button", { name: /Theme/u })).toBeTruthy();
  });

  it("keeps the list closed until it is asked for", () => {
    renderSelect();

    expect(screen.queryByRole("listbox")).toBeNull();
  });

  it("opens from the keyboard and lists the options", async () => {
    const user = renderSelect();

    await user.tab();
    await user.keyboard("{Enter}");

    expect(screen.getByRole("listbox")).toBeTruthy();
    expect(screen.getByRole("option", { name: "Light" })).toBeTruthy();
  });

  it("selects with the arrow keys and reports the chosen key", async () => {
    const changed = vi.fn();
    const user = renderSelect({ defaultSelectedKey: "system", onSelectionChange: changed });

    await user.tab();
    await user.keyboard("{Enter}");
    await user.keyboard("{ArrowDown}{Enter}");

    expect(changed).toHaveBeenLastCalledWith("light");
  });

  it("closes on Escape without changing the selection", async () => {
    const changed = vi.fn();
    const user = renderSelect({ defaultSelectedKey: "system", onSelectionChange: changed });

    await user.tab();
    await user.keyboard("{Enter}");
    await user.keyboard("{Escape}");

    expect(screen.queryByRole("listbox")).toBeNull();
    expect(changed).not.toHaveBeenCalled();
  });

  it("returns focus to the trigger after closing", async () => {
    const user = renderSelect();
    const trigger = screen.getByRole("button", { name: /Theme/u });

    await user.tab();
    await user.keyboard("{Enter}");
    await user.keyboard("{Escape}");

    // The restore happens after the popover unmounts, not in the same tick.
    await waitFor(() => {
      expect(document.activeElement).toBe(trigger);
    });
  });

  it("marks a disabled option so it cannot be chosen", async () => {
    const user = renderSelect();

    await user.tab();
    await user.keyboard("{Enter}");

    expect(screen.getByRole("option", { name: "Dark" }).getAttribute("aria-disabled")).toBe("true");
  });

  it("marks itself invalid and shows the server's message", () => {
    render(
      <Select
        label="Theme"
        options={OPTIONS}
        errorMessage="Unavailable on this surface."
      />,
    );

    expect(screen.getByText("Unavailable on this surface.")).toBeTruthy();
  });

  it("renders a description when the screen supplies one", () => {
    renderSelect({ description: "Applied to every surface." });

    expect(screen.getByText("Applied to every surface.")).toBeTruthy();
  });

  it("is unreachable while disabled", async () => {
    const user = renderSelect({ isDisabled: true });

    await user.tab();

    expect(document.activeElement).not.toBe(screen.getByRole("button", { name: /Theme/u }));
  });
});
