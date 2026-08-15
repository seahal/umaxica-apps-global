import type { ReactComponent } from "@inertiajs/react";

// Shared pieces for the per-FQDN Inertia entrypoints.
//
// Every trust boundary (base/app, base/com, auth/org, ...) boots its own Inertia application from
// its own entrypoint and globs only its own page directory, so one surface can never resolve
// another surface's page component. This module holds what is genuinely identical between them;
// the glob itself stays a literal in each entrypoint because Vite can only rewrite a literal.

/**
 * Rails sends surface-qualified component names ("base/app/groups/index") so the Inertia page
 * object stays self-describing in logs and in the browser devtools, while each entrypoint globs
 * only its own directory. A name that does not carry this surface's prefix is a cross-surface
 * render and fails loudly rather than falling through to a "Page not found" that looks like a
 * missing file.
 */
type PageModule = { default: ReactComponent };

function isPageModule(module: unknown): module is PageModule {
  if (typeof module !== "object" || module === null || !("default" in module)) {
    return false;
  }

  const { default: component } = module;
  return typeof component === "object" || typeof component === "function";
}

/**
 * Builds the `resolve` for one surface from its own eagerly globbed page directory.
 *
 * Resolution stays eager on purpose. `vite_javascript_tag` emits `modulepreload` links by walking
 * the manifest's static `imports` only, never `dynamicImports`, so a lazily resolved page chunk is
 * discovered a full round trip after the entry script runs and the Inertia root stays empty for
 * that long. Eager resolution puts the page in the preloaded static graph instead.
 *
 * The surface layout is attached here rather than by each page module: a page that forgot to
 * declare it would otherwise render without header, footer or cookie controls, and that is not a
 * mistake a page should be able to make. It is assigned as an array because Inertia 3 no longer
 * accepts a bare arrow component as `layout`.
 */
export function surfacePageResolver(
  modules: Record<string, unknown>,
  surface: string,
  layout: ReactComponent,
): (name: string) => PageModule {
  const prefix = `${surface}/`;
  const pages = new Map<string, PageModule>();

  for (const [path, module] of Object.entries(modules)) {
    const name = path.replace(/^.*\/pages\//, "").replace(/\.tsx$/, "");

    if (!isPageModule(module)) {
      throw new Error(
        `Inertia page "${name}" in src/pages/${surface} has no default export. ` +
          "A page module must export its component as the default.",
      );
    }

    pages.set(name, module);
  }

  return (name: string) => {
    if (!name.startsWith(prefix)) {
      throw new Error(
        `Inertia page "${name}" does not belong to the "${surface}" surface. ` +
          "Rendering another surface's page component is a trust boundary violation.",
      );
    }

    const page = pages.get(name);

    if (!page) {
      throw new Error(
        `Inertia page "${name}" has no component in src/pages/${surface}. ` +
          "The controller renders a page the surface cannot resolve.",
      );
    }

    page.default.layout ??= [layout];

    return page;
  };
}

/**
 * Client defaults that are part of the Rails <-> Inertia contract rather than of any one surface:
 * `brackets` matches Rack's query parsing, and the form defaults match the server error payload.
 */
export const surfaceInertiaDefaults = {
  form: {
    forceIndicesArrayFormatInFormData: false,
    withAllErrors: true,
  },
  visitOptions: () => ({ queryStringArrayFormat: "brackets" }) as const,
} as const;

/**
 * The response CSP nonce, published by the layout as `<meta property="csp-nonce">`.
 *
 * Inertia builds its progress bar and its error dialog as `<style>` elements at runtime, and
 * `script-src`/`style-src-elem` carry a nonce with no `unsafe-inline`, so those elements are
 * refused unless they are told the nonce. Vite's dev client reads the same tag by itself.
 *
 * Returns undefined rather than throwing when the tag is absent: `createInertiaApp` treats that as
 * "no nonce", which is the correct behaviour under a policy that does not use one.
 */
export function cspNonce(): string | undefined {
  return document.querySelector<HTMLMetaElement>("meta[property=csp-nonce]")?.nonce || undefined;
}

/**
 * `createInertiaApp` rejects when the root element is absent, which happens when an Inertia
 * entrypoint is loaded from a non-Inertia layout. Report that as a configuration mistake instead
 * of an unhandled rejection, and rethrow anything else.
 */
export function reportInertiaBootFailure(error: unknown): void {
  if (document.getElementById("app")) {
    throw error;
  }

  // oxlint-disable-next-line no-console
  console.error(
    "Missing Inertia root element.\n\n" +
      "This entrypoint belongs to a surface Inertia layout (app/views/layouts/<family>/<surface>/" +
      "inertia.html.erb). A non-Inertia layout must load its own entrypoint instead.",
  );
}
