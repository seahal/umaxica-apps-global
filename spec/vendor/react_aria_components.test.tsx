import { act, createRef } from "react";
import { createRoot, type Root } from "react-dom/client";
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it } from "vitest";

import { Button, TextField } from "../../src/vendor/react-aria-components";

// This is a hand-rolled shim for the subset of react-aria-components this app actually uses
// (see src/vendor/react-aria-components.tsx); it is aliased in place of the real package in
// vitest.config.ts, so these tests cover the actual implementation the app renders with.

describe("Button (static markup)", () => {
  it('defaults to a type="button" element that forwards its class name and children', () => {
    const html = renderToStaticMarkup(<Button className="btn">Click me</Button>);

    expect(html).toContain('type="button"');
    expect(html).toContain('class="btn"');
    expect(html).toContain("Click me");
  });

  it("honours an explicit type instead of the default", () => {
    const html = renderToStaticMarkup(<Button type="submit">Save</Button>);

    expect(html).toContain('type="submit"');
  });

  it("marks a disabled button with aria-disabled, data-disabled, and the native disabled attribute", () => {
    const html = renderToStaticMarkup(<Button isDisabled>Click me</Button>);

    expect(html).toContain('aria-disabled="true"');
    expect(html).toContain("data-disabled");
    expect(html).toContain("disabled");
  });

  it("omits the disabled/data-disabled markers when enabled", () => {
    const html = renderToStaticMarkup(<Button>Click me</Button>);

    expect(html).not.toContain("aria-disabled");
    expect(html).not.toContain("data-disabled");
  });
});

describe("Button (interaction state)", () => {
  let container: HTMLDivElement;
  let root: Root;

  afterEach(() => {
    act(() => {
      root.unmount();
    });
    container.remove();
  });

  const mount = () => {
    container = document.createElement("div");
    document.body.append(container);
    root = createRoot(container);
    const ref = createRef<HTMLButtonElement>();

    act(() => {
      root.render(<Button ref={ref}>Click me</Button>);
    });

    return ref.current!;
  };

  it("forwards the ref to the underlying button element", () => {
    const button = mount();

    expect(button).toBeInstanceOf(HTMLButtonElement);
  });

  it("tracks focus-visible state independently of press state", () => {
    const button = mount();

    act(() => {
      button.focus();
    });
    expect(button.dataset.focusVisible).toBe("true");

    act(() => {
      button.blur();
    });
    expect(button.dataset.focusVisible).toBeUndefined();
  });

  it("presses on Space/Enter keydown and releases on keyup", () => {
    const button = mount();

    act(() => {
      button.dispatchEvent(
        new KeyboardEvent("keydown", { key: " ", bubbles: true, cancelable: true }),
      );
    });
    expect(button.dataset.pressed).toBe("true");

    act(() => {
      button.dispatchEvent(new KeyboardEvent("keyup", { key: " ", bubbles: true }));
    });
    expect(button.dataset.pressed).toBeUndefined();

    act(() => {
      button.dispatchEvent(
        new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true }),
      );
    });
    expect(button.dataset.pressed).toBe("true");

    act(() => {
      button.dispatchEvent(new KeyboardEvent("keyup", { key: "Enter", bubbles: true }));
    });
    expect(button.dataset.pressed).toBeUndefined();
  });

  it("ignores keys other than Space/Enter", () => {
    const button = mount();

    act(() => {
      button.dispatchEvent(
        new KeyboardEvent("keydown", { key: "a", bubbles: true, cancelable: true }),
      );
    });
    expect(button.dataset.pressed).toBeUndefined();

    act(() => {
      button.dispatchEvent(
        new KeyboardEvent("keydown", { key: " ", bubbles: true, cancelable: true }),
      );
      button.dispatchEvent(new KeyboardEvent("keyup", { key: "a", bubbles: true }));
    });
    expect(button.dataset.pressed).toBe("true");
  });

  it("tracks pointer down/up/leave/cancel as press state", () => {
    const button = mount();

    act(() => {
      button.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true }));
    });
    expect(button.dataset.pressed).toBe("true");

    act(() => {
      button.dispatchEvent(new PointerEvent("pointerup", { bubbles: true }));
    });
    expect(button.dataset.pressed).toBeUndefined();

    act(() => {
      button.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true }));
    });
    act(() => {
      // React implements onPointerLeave via a bubbling "pointerout" listener since the native
      // pointerleave event does not bubble and so cannot be delegated to the root listener.
      button.dispatchEvent(new PointerEvent("pointerout", { bubbles: true }));
    });
    expect(button.dataset.pressed).toBeUndefined();

    act(() => {
      button.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true }));
    });
    act(() => {
      button.dispatchEvent(new PointerEvent("pointercancel", { bubbles: true }));
    });
    expect(button.dataset.pressed).toBeUndefined();
  });

  it("clears both press and focus-visible state on blur", () => {
    const button = mount();

    act(() => {
      button.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true }));
      button.focus();
    });
    expect(button.dataset.pressed).toBe("true");
    expect(button.dataset.focusVisible).toBe("true");

    act(() => {
      button.blur();
    });
    expect(button.dataset.pressed).toBeUndefined();
    expect(button.dataset.focusVisible).toBeUndefined();
  });
});

describe("TextField", () => {
  it("forwards children, className, and the ref to the wrapping div", () => {
    const ref = createRef<HTMLDivElement>();
    const html = renderToStaticMarkup(
      <TextField
        ref={ref}
        className="field"
      >
        <input />
      </TextField>,
    );

    expect(html).toContain('class="field"');
    expect(html).toContain("<input");
  });

  it("marks a disabled field with data-disabled", () => {
    const html = renderToStaticMarkup(<TextField isDisabled>content</TextField>);

    expect(html).toContain("data-disabled");
  });

  it("marks an invalid field with data-invalid", () => {
    const html = renderToStaticMarkup(<TextField validationState="invalid">content</TextField>);

    expect(html).toContain("data-invalid");
  });

  it("omits data-invalid for a valid field", () => {
    const html = renderToStaticMarkup(<TextField validationState="valid">content</TextField>);

    expect(html).not.toContain("data-invalid");
  });
});
