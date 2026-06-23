import { afterEach, describe, expect, it, vi } from "vite-plus/test";

const render = vi.fn();
const unmount = vi.fn();
const createRoot = vi.fn(() => {
  return {
    render,
    unmount,
  };
});

vi.mock("react-dom/client", () => {
  return {
    createRoot,
  };
});

vi.mock("@/features/react_aria_probe/ReactAriaProbe", () => {
  return {
    ReactAriaProbe: () => null,
  };
});

describe("react islands", () => {
  afterEach(() => {
    document.body.innerHTML = "";
    createRoot.mockClear();
    render.mockClear();
    unmount.mockClear();
  });

  it("mounts known islands and parses JSON props", async () => {
    const container = document.createElement("div");
    container.innerHTML = `
      <div data-react-component="ReactAriaProbe" data-react-props='{"title":"Probe"}'></div>
    `;
    document.body.append(container);

    const { mountReactIslands } = await import("../../src/entrypoints/react_islands");

    mountReactIslands(document);

    expect(createRoot).toHaveBeenCalledTimes(1);
    expect(render).toHaveBeenCalledTimes(1);
    expect(render.mock.calls[0][0].props).toMatchObject({ title: "Probe" });
  });

  it("silently skips unknown island names", async () => {
    const container = document.createElement("div");
    container.innerHTML = `
      <div data-react-component="UnknownIsland" data-react-props='{"title":"Ignored"}'></div>
    `;
    document.body.append(container);

    const { mountReactIslands } = await import("../../src/entrypoints/react_islands");

    mountReactIslands(document);

    expect(createRoot).not.toHaveBeenCalled();
    expect(render).not.toHaveBeenCalled();
  });
});
