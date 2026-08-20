// Inertia application for the auth/org FQDN. It resolves pages from src/pages/auth/org only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/auth/org/**/*.tsx", { eager: true }),
  "auth/org",
);
