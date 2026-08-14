// Inertia application for the side/app FQDN. It resolves pages from src/pages/side/app only.
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
    path: "../../pages/side/app",
    transform: surfacePageTransform("side/app"),
    lazy: false,
  },

  // Inertia builds its progress bar as a runtime <style>; without the nonce the policy
  // refuses it.
  nonce: cspNonce(),

  strictMode: true,

  defaults: surfaceInertiaDefaults,
}).catch(reportInertiaBootFailure);
