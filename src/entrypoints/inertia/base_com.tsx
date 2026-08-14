// Inertia application for the base/com FQDN. It resolves pages from src/pages/base/com only.
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
    import.meta.glob("../../pages/base/com/**/*.tsx", { eager: true }),
    "base/com",
    SurfaceLayout,
  ),

  // Inertia builds its progress bar as a runtime <style>; without the nonce the policy
  // refuses it.
  nonce: cspNonce(),

  strictMode: true,

  defaults: surfaceInertiaDefaults,
}).catch(reportInertiaBootFailure);
