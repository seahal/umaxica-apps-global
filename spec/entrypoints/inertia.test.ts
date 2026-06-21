import { beforeEach, describe, expect, test, vi } from "vite-plus/test";

vi.mock("@inertiajs/react", () => ({
  createInertiaApp: vi.fn(() => Promise.reject(new Error("test inertia error"))),
}));

describe("inertia entrypoint", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
  });

  test("logs a helpful error when the root element is missing", async () => {
    document.body.innerHTML = "";
    const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});

    await import("../../src/entrypoints/inertia.tsx");
    await Promise.resolve();

    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining("Missing root element"));
    errorSpy.mockRestore();
  });
});
