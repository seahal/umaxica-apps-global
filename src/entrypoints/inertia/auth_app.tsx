// Inertia application for the auth/app FQDN. It resolves pages from src/pages/auth/app only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/auth/app/**/*.tsx", { eager: true }),
  "auth/app",
);
