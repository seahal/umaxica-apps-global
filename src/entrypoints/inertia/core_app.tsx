// Inertia application for the core/app FQDN. It resolves pages from src/pages/core/app only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/core/app/**/*.tsx", { eager: true }),
  "core/app",
);
