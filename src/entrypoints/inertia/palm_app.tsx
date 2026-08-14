// Inertia application for the palm/app FQDN. It resolves pages from src/pages/palm/app only.
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
    path: "../../pages/palm/app",
    transform: surfacePageTransform("palm/app"),
    lazy: false,
  },

  // Inertia builds its progress bar as a runtime <style>; without the nonce the policy
  // refuses it.
  nonce: cspNonce(),

  strictMode: true,

  defaults: surfaceInertiaDefaults,
}).catch(reportInertiaBootFailure);
