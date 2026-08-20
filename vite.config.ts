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
    // One alias, matching `paths` in tsconfig.app.json. Every additional alias is a second
    // spelling for a path TypeScript and Vite must both agree on, so they are kept to one.
    alias: { "@": srcRoot },
  },
});
