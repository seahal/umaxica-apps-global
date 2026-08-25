// Inertia application for the palm/app FQDN. It resolves pages from src/pages/palm/app only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/palm/app/**/*.tsx", { eager: true }),
  "palm/app",
);
