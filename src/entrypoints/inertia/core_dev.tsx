// Inertia application for the core/dev FQDN. It resolves pages from src/pages/core/dev only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/core/dev/**/*.tsx", { eager: true }),
  "core/dev",
);
