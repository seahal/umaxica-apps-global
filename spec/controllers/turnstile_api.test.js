import { afterEach, describe, expect, it, vi } from "vitest";

import { waitForTurnstileApi } from "@/controllers/turnstile_api";

const SCRIPT_HTML = '<script src="https://challenges.cloudflare.com/turnstile/v0/api.js"></script>';

describe("waitForTurnstileApi", () => {
  afterEach(() => {
    document.head.innerHTML = "";
    delete window.turnstile;
    vi.useRealTimers();
  });

  it("resolves immediately when window.turnstile is already present", async () => {
    window.turnstile = { render: vi.fn() };

    await expect(waitForTurnstileApi("missing")).resolves.toBe(window.turnstile);
  });

  it("rejects immediately when the Turnstile script tag is not on the page", async () => {
    await expect(waitForTurnstileApi("no script tag")).rejects.toThrow("no script tag");
  });

  it("resolves once the script loads and window.turnstile becomes available", async () => {
    document.head.innerHTML = SCRIPT_HTML;
    const script = document.querySelector("script");
    const promise = waitForTurnstileApi("timed out");

    window.turnstile = { render: vi.fn() };
    script.dispatchEvent(new Event("load"));

    await expect(promise).resolves.toBe(window.turnstile);
  });

  it("rejects when the script loads but window.turnstile never appears", async () => {
    document.head.innerHTML = SCRIPT_HTML;
    const script = document.querySelector("script");
    const promise = waitForTurnstileApi("turnstile missing after load");

    script.dispatchEvent(new Event("load"));

    await expect(promise).rejects.toThrow("turnstile missing after load");
  });

  it("rejects when the script tag fires an error event", async () => {
    document.head.innerHTML = SCRIPT_HTML;
    const script = document.querySelector("script");
    const promise = waitForTurnstileApi("script failed to load");

    script.dispatchEvent(new Event("error"));

    await expect(promise).rejects.toThrow("script failed to load");
  });

  it("rejects once the timeout elapses without the script settling", async () => {
    vi.useFakeTimers();
    document.head.innerHTML = SCRIPT_HTML;

    const promise = waitForTurnstileApi("timed out", 1000);
    const assertion = expect(promise).rejects.toThrow("timed out");

    await vi.advanceTimersByTimeAsync(1000);
    await assertion;
  });
});
