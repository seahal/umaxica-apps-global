// Inertia application for the base/com FQDN. It resolves pages from src/pages/base/com only.
import { createInertiaApp } from "@inertiajs/react";

// The surface Inertia layout renders the same ERB header and footer as its Turbo layout, and the
// footer cookie and theme controls are Stimulus. Turbo is deliberately not imported: navigation out
// of the Inertia application is a full document visit.
import "../../controllers";
import "../../theme_cookie";
import {
  cspNonce,
  reportInertiaBootFailure,
  surfaceInertiaDefaults,
  surfacePageTransform,
} from "@/inertia/surface";

void createInertiaApp({
  pages: {
    path: "../../pages/base/com",
    transform: surfacePageTransform("base/com"),
    lazy: false,
  },

  // Inertia builds its progress bar as a runtime <style>; without the nonce the policy
  // refuses it.
  nonce: cspNonce(),

  strictMode: true,

  defaults: surfaceInertiaDefaults,
}).catch(reportInertiaBootFailure);
