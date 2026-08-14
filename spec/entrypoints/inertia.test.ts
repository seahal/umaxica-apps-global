import { createInertiaApp } from "@inertiajs/react";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import {
  reportInertiaBootFailure,
  surfaceInertiaDefaults,
  surfacePageTransform,
} from "@/inertia/surface";

vi.mock("@inertiajs/react", () => ({
  createInertiaApp: vi.fn(() => Promise.reject(new Error("test inertia error"))),
}));

// createInertiaApp's real declaration is a three-overload union keyed on `render`/`setup`, which
// makes the mock's captured argument type impractical to narrow precisely; every real entrypoint
// passes this shape, so tests below assert against it directly instead.
type SurfaceInertiaConfig = {
  pages: { path: string; lazy: boolean; transform: (name: string) => string };
  strictMode: boolean;
  defaults: typeof surfaceInertiaDefaults;
};

describe("surface page transform", () => {
  test("strips the surface prefix Rails sends so the surface-scoped glob can resolve the page", () => {
    expect(surfacePageTransform("base/app")("base/app/groups/index")).toBe("groups/index");
  });

  test("rejects a page belonging to another surface instead of attempting to resolve it", () => {
    expect(() => surfacePageTransform("base/app")("base/com/groups/index")).toThrow(
      /does not belong to the "base\/app" surface/,
    );
  });

  test("rejects an unqualified page name so a missing prefix is not silently accepted", () => {
    expect(() => surfacePageTransform("auth/org")("groups/index")).toThrow(
      /does not belong to the "auth\/org" surface/,
    );
  });
});

describe("surface inertia defaults", () => {
  test("visits use bracket array syntax so Rack parses array parameters", () => {
    expect(surfaceInertiaDefaults.visitOptions()).toEqual({ queryStringArrayFormat: "brackets" });
  });
});

describe("reportInertiaBootFailure", () => {
  afterEach(() => {
    document.body.innerHTML = "";
  });

  test("rethrows the original error when the Inertia root element is present", () => {
    document.body.innerHTML = '<div id="app"></div>';
    const error = new Error("boot failed for an unrelated reason");

    expect(() => reportInertiaBootFailure(error)).toThrow(error);
  });
});

describe("surface inertia entrypoint", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
  });

  test("logs a configuration error when loaded from a layout without the Inertia root element", async () => {
    document.body.innerHTML = "";
    const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});

    await import("../../src/entrypoints/inertia/base_app.tsx");
    await Promise.resolve();

    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining("Missing Inertia root element"));
    errorSpy.mockRestore();
  });
});

describe.each([
  ["auth/app", "../../src/entrypoints/inertia/auth_app.tsx"],
  ["auth/com", "../../src/entrypoints/inertia/auth_com.tsx"],
  ["auth/org", "../../src/entrypoints/inertia/auth_org.tsx"],
  ["base/com", "../../src/entrypoints/inertia/base_com.tsx"],
  ["base/org", "../../src/entrypoints/inertia/base_org.tsx"],
  ["palm/app", "../../src/entrypoints/inertia/palm_app.tsx"],
  ["side/app", "../../src/entrypoints/inertia/side_app.tsx"],
  ["side/com", "../../src/entrypoints/inertia/side_com.tsx"],
  ["side/org", "../../src/entrypoints/inertia/side_org.tsx"],
])("%s inertia entrypoint", (surface, modulePath) => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
  });

  test("wires createInertiaApp to the surface-scoped page glob", async () => {
    await import(modulePath);
    await Promise.resolve();

    expect(createInertiaApp).toHaveBeenCalledTimes(1);

    // oxlint-disable-next-line no-unsafe-type-assertion -- see SurfaceInertiaConfig comment above.
    const config = vi.mocked(createInertiaApp).mock
      .calls[0]?.[0] as unknown as SurfaceInertiaConfig;

    expect(config.pages).toMatchObject({ path: `../../pages/${surface}`, lazy: false });
    expect(config.strictMode).toBe(true);
    expect(config.defaults.visitOptions()).toEqual(surfaceInertiaDefaults.visitOptions());
    expect(config.pages.transform(`${surface}/groups/index`)).toBe("groups/index");
  });
});
