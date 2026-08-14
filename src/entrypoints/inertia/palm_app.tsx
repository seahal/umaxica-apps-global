// Inertia application for the palm/app FQDN. It resolves pages from src/pages/palm/app only.
import { createInertiaApp } from "@inertiajs/react";

import {
  cspNonce,
  reportInertiaBootFailure,
  surfaceInertiaDefaults,
  surfacePageResolver,
} from "@/inertia/surface";
import SurfaceLayout from "@/layouts/SurfaceLayout";

void createInertiaApp({
  resolve: surfacePageResolver(
    import.meta.glob("../../pages/palm/app/**/*.tsx", { eager: true }),
    "palm/app",
    SurfaceLayout,
  ),

  // Inertia builds its progress bar as a runtime <style>; without the nonce the policy
  // refuses it.
  nonce: cspNonce(),

  strictMode: true,

  defaults: surfaceInertiaDefaults,
}).catch(reportInertiaBootFailure);
