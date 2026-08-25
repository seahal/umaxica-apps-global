// Inertia application for the core/com FQDN. It resolves pages from src/pages/core/com only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/core/com/**/*.tsx", { eager: true }),
  "core/com",
);
