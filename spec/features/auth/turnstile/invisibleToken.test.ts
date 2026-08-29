// The invisible-widget token solver behind `PasskeySignInPanel`. Waiting for the Cloudflare script
// is covered by `spec/lib/turnstile.test.ts`; what belongs here is what this module decides: where
// it mounts the widget, what it hands `render`, and that every Turnstile outcome (token, error,
// expiry, and a synchronous render failure) surfaces as either the resolved token or the caller's
// error message.
import { beforeEach, describe, expect, it, vi } from "vitest";

import { solveInvisibleTurnstile } from "@/features/auth/turnstile/invisibleToken";
import type { TurnstileOptions } from "@/lib/turnstile";

import { present } from "../../../support/present";

const ERROR_MESSAGE = "Verification failed";

let rendered: { container: HTMLElement; options: TurnstileOptions }[];
let render: ReturnType<typeof vi.fn>;

function stubTurnstileScript() {
  document.head.innerHTML =
    '<script src="https://challenges.cloudflare.com/turnstile/v0/api.js"></script>';
}

beforeEach(() => {
  document.head.innerHTML = "";
  document.body.innerHTML = "";
  rendered = [];
  render = vi.fn((container: HTMLElement, options: TurnstileOptions) => {
    rendered.push({ container, options });
    return "widget-1";
  });
  vi.stubGlobal("turnstile", { render, execute: vi.fn(), remove: vi.fn() });
  stubTurnstileScript();
});

describe("solveInvisibleTurnstile", () => {
  it("rejects without rendering a widget when no site key is configured", async () => {
    await expect(solveInvisibleTurnstile("", ERROR_MESSAGE, null)).rejects.toThrow(ERROR_MESSAGE);

    expect(render).not.toHaveBeenCalled();
  });

  it("mounts a hidden invisible-size widget on the given host and resolves with its token", async () => {
    const host = document.createElement("div");
    document.body.append(host);

    const promise = solveInvisibleTurnstile("site-key", ERROR_MESSAGE, host);

    await vi.waitFor(() => expect(render).toHaveBeenCalledTimes(1));
    const { container, options } = present(rendered[0], "the rendered widget");
    expect(container.parentElement).toBe(host);
    expect(container.hidden).toBe(true);
    expect(options.sitekey).toBe("site-key");
    expect(options.size).toBe("invisible");

    options.callback("solved-token");

    await expect(promise).resolves.toBe("solved-token");
  });

  it("mounts on document.body when no host element is given", async () => {
    const promise = solveInvisibleTurnstile("site-key", ERROR_MESSAGE, null);

    await vi.waitFor(() => expect(render).toHaveBeenCalledTimes(1));
    expect(rendered[0]?.container.parentElement).toBe(document.body);

    rendered[0]?.options.callback("solved-token");
    await expect(promise).resolves.toBe("solved-token");
  });

  it("rejects with the caller's error message when the widget reports an error", async () => {
    const promise = solveInvisibleTurnstile("site-key", ERROR_MESSAGE, null);

    await vi.waitFor(() => expect(render).toHaveBeenCalledTimes(1));
    rendered[0]?.options["error-callback"]?.("network-error");

    await expect(promise).rejects.toThrow(ERROR_MESSAGE);
  });

  it("rejects with the caller's error message when the challenge expires", async () => {
    const promise = solveInvisibleTurnstile("site-key", ERROR_MESSAGE, null);

    await vi.waitFor(() => expect(render).toHaveBeenCalledTimes(1));
    rendered[0]?.options["expired-callback"]?.();

    await expect(promise).rejects.toThrow(ERROR_MESSAGE);
  });

  it("rejects with the caller's error message when render throws synchronously", async () => {
    const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    render.mockImplementation(() => {
      throw new Error("widget host is detached");
    });

    await expect(solveInvisibleTurnstile("site-key", ERROR_MESSAGE, null)).rejects.toThrow(
      ERROR_MESSAGE,
    );

    expect(errorSpy).toHaveBeenCalledWith("Turnstile token request failed:", expect.any(Error));
    errorSpy.mockRestore();
  });
});
