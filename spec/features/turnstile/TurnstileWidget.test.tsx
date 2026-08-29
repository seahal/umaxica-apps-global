import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { beforeEach, describe, expect, it, vi } from "vitest";

// React port of the `turnstile` Stimulus controller. Waiting for the Cloudflare script is covered
// by `spec/lib/turnstile.test.ts`; what belongs here is what this component decides: what it hands
// `render`, where the token lands, and how each outcome (token, error, expiry, timeout,
// unsupported) is published.
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import type { TurnstileOptions } from "@/lib/turnstile";

declare global {
  // React reads this flag off the global object to decide whether `act` is allowed.
  var IS_REACT_ACT_ENVIRONMENT: boolean;
}
globalThis.IS_REACT_ACT_ENVIRONMENT = true;

let container: HTMLDivElement;
let root: Root | null;

const mount = (element: React.ReactElement) => {
  container = document.createElement("div");
  document.body.append(container);
  root = createRoot(container);
  act(() => {
    root?.render(element);
  });
};

const unmount = () => {
  act(() => {
    root?.unmount();
  });
  container.remove();
  root = null;
};

const flush = async () => {
  await act(async () => {
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
  });
};

let rendered: { container: HTMLElement; options: TurnstileOptions }[];
let render: ReturnType<typeof vi.fn>;
let execute: ReturnType<typeof vi.fn>;
let remove: ReturnType<typeof vi.fn>;

function stubTurnstileScript() {
  document.head.innerHTML =
    '<script src="https://challenges.cloudflare.com/turnstile/v0/api.js"></script>';
}

beforeEach(() => {
  document.head.innerHTML = "";
  rendered = [];
  render = vi.fn((widgetContainer: HTMLElement, options: TurnstileOptions) => {
    rendered.push({ container: widgetContainer, options });
    return "widget-1";
  });
  execute = vi.fn();
  remove = vi.fn();
  vi.stubGlobal("turnstile", { render, execute, remove });
  stubTurnstileScript();
});

describe("TurnstileWidget", () => {
  it("renders the widget with the site key alone when no action or cdata was given", async () => {
    mount(<TurnstileWidget site_key="site-key" />);

    await flush();

    expect(render).toHaveBeenCalledTimes(1);
    expect(rendered[0]?.options.sitekey).toBe("site-key");
    expect(rendered[0]?.options).not.toHaveProperty("action");
    expect(rendered[0]?.options).not.toHaveProperty("cData");
    unmount();
  });

  it("carries the action and cdata when the server sent them", async () => {
    mount(
      <TurnstileWidget
        site_key="site-key"
        action="sign-in"
        cdata="ticket-1"
      />,
    );

    await flush();

    expect(rendered[0]?.options.action).toBe("sign-in");
    expect(rendered[0]?.options.cData).toBe("ticket-1");
    unmount();
  });

  it("writes the token to the hidden field and calls onToken", async () => {
    const onToken = vi.fn();
    mount(
      <TurnstileWidget
        site_key="site-key"
        onToken={onToken}
      />,
    );
    await flush();

    act(() => {
      rendered[0]?.options.callback("solved-token");
    });

    expect(
      container.querySelector<HTMLInputElement>("input[name='cf-turnstile-response']")?.value,
    ).toBe("solved-token");
    expect(onToken).toHaveBeenCalledWith("solved-token");
    unmount();
  });

  it("executes immediately in execute mode", async () => {
    mount(
      <TurnstileWidget
        site_key="site-key"
        mode="execute"
      />,
    );

    await flush();

    expect(execute).toHaveBeenCalledWith("widget-1");
    unmount();
  });

  it("does not execute in the default render mode", async () => {
    mount(<TurnstileWidget site_key="site-key" />);

    await flush();

    expect(execute).not.toHaveBeenCalled();
    unmount();
  });

  it("clears the token when the widget reports an error", async () => {
    const onToken = vi.fn();
    mount(
      <TurnstileWidget
        site_key="site-key"
        onToken={onToken}
      />,
    );
    await flush();
    act(() => {
      rendered[0]?.options.callback("solved-token");
    });

    let outcome: boolean | void | undefined;
    act(() => {
      outcome = rendered[0]?.options["error-callback"]?.("network-error");
    });

    expect(outcome).toBe(true);
    expect(
      container.querySelector<HTMLInputElement>("input[name='cf-turnstile-response']")?.value,
    ).toBe("");
    expect(onToken).toHaveBeenLastCalledWith("");
    unmount();
  });

  it("clears the token when the challenge expires", async () => {
    mount(<TurnstileWidget site_key="site-key" />);
    await flush();
    act(() => {
      rendered[0]?.options.callback("solved-token");
    });

    act(() => {
      rendered[0]?.options["expired-callback"]?.();
    });

    expect(
      container.querySelector<HTMLInputElement>("input[name='cf-turnstile-response']")?.value,
    ).toBe("");
    unmount();
  });

  it("clears the token when the widget times out", async () => {
    mount(<TurnstileWidget site_key="site-key" />);
    await flush();
    act(() => {
      rendered[0]?.options.callback("solved-token");
    });

    act(() => {
      rendered[0]?.options["timeout-callback"]?.();
    });

    expect(
      container.querySelector<HTMLInputElement>("input[name='cf-turnstile-response']")?.value,
    ).toBe("");
    unmount();
  });

  it("clears the token when the browser is unsupported", async () => {
    mount(<TurnstileWidget site_key="site-key" />);
    await flush();
    act(() => {
      rendered[0]?.options.callback("solved-token");
    });

    act(() => {
      rendered[0]?.options["unsupported-callback"]?.();
    });

    expect(
      container.querySelector<HTMLInputElement>("input[name='cf-turnstile-response']")?.value,
    ).toBe("");
    unmount();
  });

  it("shows its own failure message when the challenge cannot be presented", async () => {
    vi.stubGlobal("turnstile", undefined);
    document.head.innerHTML = "";
    mount(<TurnstileWidget site_key="site-key" />);

    await flush();

    expect(container.querySelector("[role='alert']")?.textContent).toBe(
      "Security verification failed. Please refresh and try again.",
    );
    expect(render).not.toHaveBeenCalled();
  });

  it("shows the caller's own error message when one was given", async () => {
    vi.stubGlobal("turnstile", undefined);
    document.head.innerHTML = "";
    mount(
      <TurnstileWidget
        site_key="site-key"
        error_message="読み込みに失敗しました"
      />,
    );

    await flush();

    expect(container.querySelector("[role='alert']")?.textContent).toBe("読み込みに失敗しました");
  });

  it("does not render the widget when unmounted before the resolved API continues", async () => {
    // `window.turnstile` is already set, so `waitForTurnstileApi` resolves on an already-settled
    // promise; unmounting in the same tick still lands before that resolution is observed.
    mount(<TurnstileWidget site_key="site-key" />);
    unmount();

    await flush();

    expect(render).not.toHaveBeenCalled();
  });

  it("removes the widget on unmount", async () => {
    mount(<TurnstileWidget site_key="site-key" />);
    await flush();

    unmount();

    expect(remove).toHaveBeenCalledWith("widget-1");
  });

  it("does nothing when the component unmounts before the API resolves", async () => {
    // A script present but silent (no `load`, no `error`) leaves `waitForTurnstileApi` pending
    // until its own timeout, which is what a slow Cloudflare load looks like.
    vi.stubGlobal("turnstile", undefined);
    vi.useFakeTimers();
    try {
      mount(<TurnstileWidget site_key="site-key" />);
      unmount();

      await act(async () => {
        await vi.runAllTimersAsync();
      });

      expect(render).not.toHaveBeenCalled();
    } finally {
      vi.useRealTimers();
    }
  });
});
