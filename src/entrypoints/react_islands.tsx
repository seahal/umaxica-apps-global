import type { ComponentType } from "react";
import { createRoot, type Root } from "react-dom/client";

import { ReactAriaProbe } from "@/features/react_aria_probe/ReactAriaProbe";

type ReactComponentProps = Record<string, unknown>;
type ReactIslandComponent = ComponentType<ReactComponentProps>;

const reactIslands: Record<string, ReactIslandComponent> = {
  ReactAriaProbe,
};

const mountedRoots = new WeakMap<Element, Root>();
const mountedElements = new Set<Element>();
let listenersRegistered = false;

export function parseReactIslandProps(value: string | null | undefined): ReactComponentProps {
  if (!value) {
    return {};
  }

  try {
    const parsed = JSON.parse(value);

    if (parsed === null || Array.isArray(parsed) || typeof parsed !== "object") {
      return {};
    }

    return parsed as ReactComponentProps;
  } catch {
    return {};
  }
}

export function mountReactIslands(root: ParentNode = document): void {
  const elements = root.querySelectorAll<HTMLElement>("[data-react-component]");

  elements.forEach((element) => {
    if (mountedRoots.has(element)) {
      return;
    }

    const componentName = element.dataset.reactComponent;

    if (!componentName) {
      return;
    }

    const Component = reactIslands[componentName];

    if (!Component) {
      return;
    }

    const props = parseReactIslandProps(element.dataset.reactProps);
    const reactRoot = createRoot(element);

    mountedRoots.set(element, reactRoot);
    mountedElements.add(element);
    reactRoot.render(<Component {...props} />);
  });
}

function unmountReactIslands(): void {
  mountedElements.forEach((element) => {
    const reactRoot = mountedRoots.get(element);

    if (reactRoot) {
      reactRoot.unmount();
      mountedRoots.delete(element);
    }
  });

  mountedElements.clear();
}

export function registerReactIslands(): void {
  if (listenersRegistered) {
    mountReactIslands();
    return;
  }

  listenersRegistered = true;
  document.addEventListener("turbo:load", () => {
    mountReactIslands();
  });
  document.addEventListener("turbo:before-cache", () => {
    unmountReactIslands();
  });
  mountReactIslands();
}
