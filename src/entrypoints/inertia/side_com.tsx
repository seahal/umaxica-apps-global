// Inertia application for the side/com FQDN. It resolves pages from src/pages/side/com only.
import { createInertiaApp } from "@inertiajs/react";

import "../../theme_cookie";
import {
  cspNonce,
  reportInertiaBootFailure,
  surfaceInertiaDefaults,
  surfacePageTransform,
} from "@/inertia/surface";

void createInertiaApp({
  pages: {
    path: "../../pages/side/com",
    transform: surfacePageTransform("side/com"),
    lazy: false,
  },

  // Inertia builds its progress bar as a runtime <style>; without the nonce the policy
  // refuses it.
  nonce: cspNonce(),

  strictMode: true,

  defaults: surfaceInertiaDefaults,
}).catch(reportInertiaBootFailure);
