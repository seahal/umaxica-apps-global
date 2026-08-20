// Inertia application for the auth/com FQDN. It resolves pages from src/pages/auth/com only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/auth/com/**/*.tsx", { eager: true }),
  "auth/com",
);
