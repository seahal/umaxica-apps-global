// Inertia application for the side/app FQDN. It resolves pages from src/pages/side/app only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/side/app/**/*.tsx", { eager: true }),
  "side/app",
);
