import { describe, expect, it, vi } from "vitest";

// application.ts is the shared Turbo/Stimulus/React-islands bootstrap imported by every surface
// that ships a JavaScript bundle. Its dependencies are unit-tested independently (Turbo itself,
// spec/controllers/index.test.js, spec/entrypoints/react_islands.test.ts,
// spec/entrypoints/theme_cookie.test.js); this test only verifies application.ts wires them up.
const registerReactIslands = vi.fn();

vi.mock("@hotwired/turbo-rails", () => ({}));
vi.mock("../../src/controllers", () => ({}));
vi.mock("../../src/entrypoints/react_islands", () => ({ registerReactIslands }));
vi.mock("../../src/theme_cookie", () => ({}));

describe("application entrypoint", () => {
  it("registers React islands on load", async () => {
    await import("../../src/entrypoints/application.ts");

    expect(registerReactIslands).toHaveBeenCalledTimes(1);
  });
});
