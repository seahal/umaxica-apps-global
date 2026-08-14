import { afterEach, describe, expect, it, vi } from "vitest";

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

  it("silently skips an element with an empty component name", async () => {
    const container = document.createElement("div");
    container.innerHTML = `<div data-react-component=""></div>`;
    document.body.append(container);

    const { mountReactIslands } = await import("../../src/entrypoints/react_islands");

    mountReactIslands(document);

    expect(createRoot).not.toHaveBeenCalled();
  });

  it("does not remount an element that is already mounted", async () => {
    const container = document.createElement("div");
    container.innerHTML = `<div data-react-component="ReactAriaProbe"></div>`;
    document.body.append(container);

    const { mountReactIslands } = await import("../../src/entrypoints/react_islands");

    mountReactIslands(document);
    mountReactIslands(document);

    expect(createRoot).toHaveBeenCalledTimes(1);
  });

  it("falls back to empty props for a value that is not valid JSON", async () => {
    const container = document.createElement("div");
    container.innerHTML = `
      <div data-react-component="ReactAriaProbe" data-react-props="not-json"></div>
    `;
    document.body.append(container);

    const { mountReactIslands } = await import("../../src/entrypoints/react_islands");

    mountReactIslands(document);

    expect(render.mock.calls[0][0].props).toEqual({});
  });

  it("falls back to empty props for JSON that parses to an array or null", async () => {
    const { parseReactIslandProps } = await import("../../src/entrypoints/react_islands");

    expect(parseReactIslandProps("[1,2,3]")).toEqual({});
    expect(parseReactIslandProps("null")).toEqual({});
  });

  it("registers turbo:load/turbo:before-cache listeners once and mounts/unmounts islands", async () => {
    vi.resetModules();

    const container = document.createElement("div");
    container.innerHTML = `<div data-react-component="ReactAriaProbe"></div>`;
    document.body.append(container);

    const { registerReactIslands } = await import("../../src/entrypoints/react_islands");

    registerReactIslands();

    expect(createRoot).toHaveBeenCalledTimes(1);

    document.dispatchEvent(new Event("turbo:before-cache"));

    expect(unmount).toHaveBeenCalledTimes(1);

    createRoot.mockClear();
    document.dispatchEvent(new Event("turbo:load"));

    expect(createRoot).toHaveBeenCalledTimes(1);

    // A second call with listeners already registered mounts directly instead of
    // re-registering the turbo:load/turbo:before-cache listeners. Unmount first so the
    // element is eligible to be mounted again.
    document.dispatchEvent(new Event("turbo:before-cache"));
    createRoot.mockClear();
    registerReactIslands();

    expect(createRoot).toHaveBeenCalledTimes(1);

    // Registering a second time did not add a second turbo:load listener.
    createRoot.mockClear();
    document.dispatchEvent(new Event("turbo:before-cache"));
    document.dispatchEvent(new Event("turbo:load"));

    expect(createRoot).toHaveBeenCalledTimes(1);
  });
});
