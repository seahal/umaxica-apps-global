// Inertia application for the side/com FQDN. It resolves pages from src/pages/side/com only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/side/com/**/*.tsx", { eager: true }),
  "side/com",
);
