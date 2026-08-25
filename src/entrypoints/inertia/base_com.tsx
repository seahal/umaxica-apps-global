// Inertia application for the base/com FQDN. It resolves pages from src/pages/base/com only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/base/com/**/*.tsx", { eager: true }),
  "base/com",
);
