import { createInertiaApp } from "@inertiajs/react";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import {
  reportInertiaBootFailure,
  surfaceInertiaDefaults,
  surfacePageResolver,
} from "@/inertia/surface";

vi.mock("@inertiajs/react", () => ({
  createInertiaApp: vi.fn(() => Promise.reject(new Error("test inertia error"))),
}));

// createInertiaApp's real declaration is a three-overload union keyed on `render`/`setup`, which
// makes the mock's captured argument type impractical to narrow precisely; every real entrypoint
// passes this shape, so tests below assert against it directly instead.
type SurfaceInertiaConfig = {
  resolve: (name: string) => { default: { layout?: unknown } };
  strictMode: boolean;
  defaults: typeof surfaceInertiaDefaults;
};

function pageModules(surface: string, names: string[]) {
  return Object.fromEntries(
    names.map((name) => [`../../pages/${surface}/${name}.tsx`, { default: () => null }]),
  );
}

const LAYOUT = () => null;

describe("surface page resolver", () => {
  test("resolves a page of its own surface from the surface-scoped glob", () => {
    const resolve = surfacePageResolver(
      pageModules("base/app", ["groups/index"]),
      "base/app",
      LAYOUT,
    );

    expect(resolve("base/app/groups/index")).toBeDefined();
  });

  test("attaches the surface layout so no page can render without chrome", () => {
    const resolve = surfacePageResolver(
      pageModules("base/app", ["groups/index"]),
      "base/app",
      LAYOUT,
    );

    expect(resolve("base/app/groups/index").default.layout).toEqual([LAYOUT]);
  });

  test("keeps a layout a page declared for itself", () => {
    const modules = pageModules("base/app", ["groups/index"]);
    const own = () => null;
    (
      modules["../../pages/base/app/groups/index.tsx"] as { default: { layout?: unknown } }
    ).default.layout = [own];
    const resolve = surfacePageResolver(modules, "base/app", LAYOUT);

    expect(resolve("base/app/groups/index").default.layout).toEqual([own]);
  });

  test("rejects a page belonging to another surface instead of attempting to resolve it", () => {
    const resolve = surfacePageResolver(
      pageModules("base/app", ["groups/index"]),
      "base/app",
      LAYOUT,
    );

    expect(() => resolve("base/com/groups/index")).toThrow(
      /does not belong to the "base\/app" surface/,
    );
  });

  test("rejects an unqualified page name so a missing prefix is not silently accepted", () => {
    const resolve = surfacePageResolver(
      pageModules("auth/org", ["groups/index"]),
      "auth/org",
      LAYOUT,
    );

    expect(() => resolve("groups/index")).toThrow(/does not belong to the "auth\/org" surface/);
  });

  test("fails loudly when the surface has no component for a page the controller rendered", () => {
    const resolve = surfacePageResolver(
      pageModules("base/app", ["groups/index"]),
      "base/app",
      LAYOUT,
    );

    expect(() => resolve("base/app/groups/show")).toThrow(
      /has no component in src\/pages\/base\/app/,
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

  test("wires createInertiaApp to a resolver scoped to its own surface", async () => {
    await import(modulePath);
    await Promise.resolve();

    expect(createInertiaApp).toHaveBeenCalledTimes(1);

    // oxlint-disable-next-line no-unsafe-type-assertion -- see SurfaceInertiaConfig comment above.
    const config = vi.mocked(createInertiaApp).mock
      .calls[0]?.[0] as unknown as SurfaceInertiaConfig;

    expect(config.strictMode).toBe(true);
    expect(config.defaults.visitOptions()).toEqual(surfaceInertiaDefaults.visitOptions());
    // The resolver is built for this surface only, so another surface's page is refused.
    expect(() => config.resolve("other/surface/groups/index")).toThrow(
      new RegExp(`does not belong to the "${surface}" surface`),
    );
  });
});
