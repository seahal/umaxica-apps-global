// Inertia application for the auth/app FQDN. It resolves pages from src/pages/auth/app only.
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
    import.meta.glob("../../pages/auth/app/**/*.tsx", { eager: true }),
    "auth/app",
    SurfaceLayout,
  ),

  // Inertia builds its progress bar as a runtime <style>; without the nonce the policy
  // refuses it.
  nonce: cspNonce(),

  strictMode: true,

  defaults: surfaceInertiaDefaults,
}).catch(reportInertiaBootFailure);
