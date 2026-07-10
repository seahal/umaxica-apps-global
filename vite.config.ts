import { fileURLToPath } from "node:url";

import inertia from "@inertiajs/vite";
import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import RubyPlugin from "vite-plugin-ruby";

const srcRoot = fileURLToPath(new URL("./src", import.meta.url));

export default defineConfig({
  plugins: [RubyPlugin(), tailwindcss(), inertia(), react()],
  resolve: {
    alias: {
      "@": srcRoot,
      "@components": fileURLToPath(new URL("./src/components", import.meta.url)),
      "@controllers": fileURLToPath(new URL("./src/controllers", import.meta.url)),
      "@entrypoints": fileURLToPath(new URL("./src/entrypoints", import.meta.url)),
      "@styles": fileURLToPath(new URL("./src/styles", import.meta.url)),
      "react-aria-components": fileURLToPath(
        new URL("./src/vendor/react-aria-components.tsx", import.meta.url),
      ),
    },
  },
});
