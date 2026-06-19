const defaultTheme = require("tailwindcss/defaultTheme");
const plugin = require("tailwindcss/plugin");

module.exports = {
  darkMode: "class",
  content: [
    "./public/*.html",
    "./app/helpers/**/*.rb",
    "./src/**/*.js",
    "./app/views/**/*.{erb,haml,html,slim}",
  ],
  theme: {
    extend: {
      fontFamily: { sans: ["Inter var", ...defaultTheme.fontFamily.sans] },
      colors: {
        bg: "hsl(var(--bg))",
        fg: "hsl(var(--fg))",
        muted: { DEFAULT: "hsl(var(--muted))", fg: "hsl(var(--muted-fg))" },
        card: { DEFAULT: "hsl(var(--card))", fg: "hsl(var(--card-fg))" },
        primary: { DEFAULT: "hsl(var(--primary))", fg: "hsl(var(--primary-fg))" },
        danger: { DEFAULT: "hsl(var(--danger))", fg: "hsl(var(--danger-fg))" },
        border: "hsl(var(--border))",
        ring: "hsl(var(--ring))",
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),
    require("@tailwindcss/container-queries"),
    plugin(({ addBase, theme }) => {
      addBase({
        "a:link": { color: theme("colors.blue.600") },
        "a:visited": { color: theme("colors.blue.600") },
      });
    }),
  ],
};
