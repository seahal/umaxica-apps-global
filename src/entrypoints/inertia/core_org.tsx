// Inertia application for the core/org FQDN. It resolves pages from src/pages/core/org only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/core/org/**/*.tsx", { eager: true }),
  "core/org",
);
