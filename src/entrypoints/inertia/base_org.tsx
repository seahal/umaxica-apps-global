// Inertia application for the base/org FQDN. It resolves pages from src/pages/base/org only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/base/org/**/*.tsx", { eager: true }),
  "base/org",
);
