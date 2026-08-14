// Inertia application for the auth/com FQDN. It resolves pages from src/pages/auth/com only.
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
    path: "../../pages/auth/com",
    transform: surfacePageTransform("auth/com"),
    lazy: false,
  },

  // Inertia builds its progress bar as a runtime <style>; without the nonce the policy
  // refuses it.
  nonce: cspNonce(),

  strictMode: true,

  defaults: surfaceInertiaDefaults,
}).catch(reportInertiaBootFailure);
