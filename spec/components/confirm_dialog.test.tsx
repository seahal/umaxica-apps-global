import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";

// The shared confirmation the destructive actions go through. Every string it shows is a prop, so
// these tests assert the copy travels through untouched and that the action fires only on accept.
const { ConfirmDialog, useConfirm } = await import("@/components/ConfirmDialog");

let container: HTMLDivElement | undefined;
let root: Root | undefined;

const mount = (element: React.ReactElement) => {
  container = document.createElement("div");
  document.body.append(container);
  const created = createRoot(container);
  root = created;
  act(() => {
    created.render(element);
  });
};

const dialogButtons = () => [
  ...(container?.querySelector("dialog[open]")?.querySelectorAll("button") ?? []),
];

const click = (element: Element | undefined) => {
  act(() => {
    element?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  });
};

afterEach(() => {
  if (root) {
    act(() => {
      root?.unmount();
    });
    container?.remove();
    root = undefined;
    container = undefined;
  }
});

const accepted = vi.fn();

function Subject({ cancelLabel }: { cancelLabel?: string }) {
  const { confirm, dialog } = useConfirm();

  return (
    <div>
      <button
        type="button"
        onClick={() =>
          confirm(
            { message: "セッションを失効しますか？", confirmLabel: "失効", cancelLabel },
            () => accepted(),
          )
        }
      >
        revoke
      </button>
      {dialog}
    </div>
  );
}

describe("ConfirmDialog markup", () => {
  it("renders nothing until a confirmation is pending", () => {
    const markup = renderToStaticMarkup(
      <ConfirmDialog
        pending={null}
        onDismiss={() => undefined}
      />,
    );

    expect(markup).toContain("<dialog");
    expect(markup).not.toContain("<button");
  });

  it("labels itself with the server's confirmation copy", () => {
    const markup = renderToStaticMarkup(
      <ConfirmDialog
        pending={{ message: "本当に削除しますか？", confirmLabel: "削除", accept: () => undefined }}
        onDismiss={() => undefined}
      />,
    );

    expect(markup).toContain("本当に削除しますか？");
    expect(markup).toContain("削除");
    expect(markup).toMatch(/aria-labelledby="[^"]+"/);
  });
});

describe("useConfirm", () => {
  afterEach(() => {
    accepted.mockClear();
  });

  it("runs the action only once the actor accepts", () => {
    mount(<Subject />);

    click(container?.querySelector("button") ?? undefined);
    expect(container?.querySelector("dialog[open]")?.textContent).toContain(
      "セッションを失効しますか？",
    );

    click(dialogButtons()[1]);
    expect(accepted).toHaveBeenCalledTimes(1);
    expect(container?.querySelector("dialog[open]")).toBeNull();
  });

  it("runs nothing when the actor declines", () => {
    mount(<Subject />);

    click(container?.querySelector("button") ?? undefined);
    click(dialogButtons()[0]);

    expect(accepted).not.toHaveBeenCalled();
    expect(container?.querySelector("dialog[open]")).toBeNull();
  });

  it("closes on Escape without running the action", () => {
    mount(<Subject />);

    click(container?.querySelector("button") ?? undefined);
    const dialog = container?.querySelector("dialog");
    act(() => {
      dialog?.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    });

    expect(accepted).not.toHaveBeenCalled();
    expect(container?.querySelector("dialog[open]")).toBeNull();
  });

  it("shows the server's decline label when the screen carries one", () => {
    mount(<Subject cancelLabel="やめる" />);

    click(container?.querySelector("button") ?? undefined);

    expect(dialogButtons()[0]?.textContent).toBe("やめる");
    expect(dialogButtons()[1]?.textContent).toBe("失効");
  });

  it("focuses the decline control, which is the safe answer", () => {
    mount(<Subject cancelLabel="やめる" />);

    click(container?.querySelector("button") ?? undefined);

    expect(document.activeElement).toBe(dialogButtons()[0]);
  });
});
