// Inertia application for the side/org FQDN. It resolves pages from src/pages/side/org only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/side/org/**/*.tsx", { eager: true }),
  "side/org",
);
