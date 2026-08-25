// Inertia application for the base/app FQDN. It resolves pages from src/pages/base/app only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/base/app/**/*.tsx", { eager: true }),
  "base/app",
);
