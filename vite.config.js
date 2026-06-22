import { fileURLToPath } from "node:url";

import inertia from "@inertiajs/vite";
import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import RubyPlugin from "vite-plugin-ruby";
import { defineConfig } from "vite-plus";

const repoRoot = import.meta.dirname;
const srcRoot = fileURLToPath(new URL("./src", import.meta.url));
const specRoot = fileURLToPath(new URL("./spec", import.meta.url));

export default defineConfig({
  plugins: [RubyPlugin(), tailwindcss(), inertia(), react()],
  resolve: {
    alias: {
      "@": srcRoot,
      "@components": fileURLToPath(new URL("./src/components", import.meta.url)),
      "@controllers": fileURLToPath(new URL("./src/controllers", import.meta.url)),
      "@entrypoints": fileURLToPath(new URL("./src/entrypoints", import.meta.url)),
      "react-aria-components": fileURLToPath(
        new URL("./src/vendor/react-aria-components.tsx", import.meta.url),
      ),
      "@styles": fileURLToPath(new URL("./src/styles", import.meta.url)),
    },
  },
  staged: {
    "*": "vp check && vp test run --coverage",
  },
  test: {
    globals: true,
    allowOnly: false,
    dangerouslyIgnoreUnhandledErrors: false,
    environment: "jsdom",
    passWithNoTests: false,
    retry: 0,
    // Anchor test discovery to the repo root so spec/ is found when Vite's
    // source code directory differs from the test root.
    root: repoRoot,
    include: [`${specRoot}/**/*.{test,spec}.{ts,tsx,js,jsx}`],
    exclude: [
      "**/node_modules/**",
      "**/vendor/**",
      "**/.ruby-lsp/**",
      "**/.pnpm-store/**",
      "**/tmp/**",
      "**/dist/**",
      "**/build/**",
      "**/coverage/**",
    ],
    coverage: {
      provider: "v8",
      reportsDirectory: "coverage",
      reporter: ["text", "html", "lcov", "json-summary"],
      include: [`${srcRoot}/**/*.{js,ts,jsx,tsx}`],
      exclude: [
        `${srcRoot}/**/*.d.ts`,
        `${srcRoot}/**/*.stories.{ts,tsx,js,jsx}`,
        `${srcRoot}/**/__fixtures__/**`,
        "**/node_modules/**",
        "**/dist/**",
        "**/build/**",
        "**/coverage/**",
        "public/vite/**",
      ],
      thresholds: {
        branches: 80,
        functions: 80,
        lines: 80,
        perFile: false,
        statements: 80,
      },
    },
  },
  fmt: {
    // ============================================================
    // 行の長さ: 100文字（rubocop の LineLength/Max と統一）
    // ============================================================
    printWidth: 100,

    // ============================================================
    // インデント: スペース2つ（Ruby 規約と統一）
    // ============================================================
    tabWidth: 2,
    useTabs: false,

    // ============================================================
    // セミコロン: 必須
    // ============================================================
    semi: true,

    // ============================================================
    // クォート: ダブルクォート（rubocop Style/StringLiterals と統一）
    // ============================================================
    singleQuote: false,
    jsxSingleQuote: false,
    quoteProps: "as-needed",

    // ============================================================
    // 末尾カンマ: 複数行では常に付与（最も strict な設定）
    // ============================================================
    trailingComma: "all",

    // ============================================================
    // ブラケット・括弧
    // ============================================================
    bracketSpacing: true,
    bracketSameLine: false,

    // ============================================================
    // アロー関数: 常に括弧を付与
    // ============================================================
    arrowParens: "always",

    // ============================================================
    // HTML属性: 1行1属性（strict モード）
    // ============================================================
    singleAttributePerLine: true,

    // ============================================================
    // Markdown: 常に折り返し（printWidth に従う）
    // ============================================================
    proseWrap: "always",

    // ============================================================
    // 行末: LF 統一
    // ============================================================
    endOfLine: "lf",

    // ============================================================
    // 最終行: 必ず改行を挿入
    // ============================================================
    insertFinalNewline: true,

    // ============================================================
    // 組み込み言語フォーマット: 自動検出
    // ============================================================
    embeddedLanguageFormatting: "auto",

    // ============================================================
    // 実験的機能
    // ============================================================
    // import 文のソート（アルファベット順）
    experimentalSortImports: {},

    // package.json キーのソート
    experimentalSortPackageJson: true,

    // ============================================================
    // 無視するパス（oxlint の ignorePatterns と統一）
    // ============================================================
    ignorePatterns: [
      "node_modules/**",
      "vendor/**",
      "tmp/**",
      "dist/**",
      "build/**",
      "coverage/**",
      ".ruby-lsp/**",
      "public/assets/**",
      "public/packs/**",

      // Ruby / ERB / TOML / YAML は除外
      "**/*.rb",
      "**/*.erb",
      "**/*.yml",
      "**/*.yaml",
      "**/*.toml",
      "Gemfile",
      "Gemfile.lock",
      "Rakefile",
      "config/database.yml",

      // スキーマ等の自動生成 JSON は除外
      "db/**",
      "log/**",
    ],
  },
  lint: {
    plugins: ["import", "promise", "unicorn", "typescript", "node", "oxc"],
    env: {
      browser: true,
      node: true,
      es2024: true,
    },
    settings: {
      react: {
        version: "18.2.0",
      },
    },
    categories: {
      correctness: "error",
      suspicious: "error",
      pedantic: "off",
      style: "off",
      perf: "off",
      restriction: "off",
    },
    rules: {
      "no-console": "error",
      "no-debugger": "error",
      "no-alert": "error",
      "no-duplicate-imports": "error",
      "import/no-duplicates": "error",
      curly: "error",
      "prefer-destructuring": "error",
      "class-methods-use-this": "off",
      "capitalized-comments": "off",
      "func-style": "off",
      "sort-imports": "off",
      "no-magic-numbers": "off",
      "import/no-unassigned-import": "off",
      "import/no-default-export": "off",
      "import/no-named-export": "off",
      "import/no-anonymous-default-export": "off",
      "import/prefer-default-export": "off",
      "unicorn/filename-case": "off",
      "unicorn/no-anonymous-default-export": "off",
      "unicorn/prefer-global-this": "off",
      "unicorn/no-document-cookie": "off",
      "unicorn/no-null": "off",
      "unicorn/prefer-add-event-listener": "off",
      "unicorn/prefer-dom-node-append": "off",
      "unicorn/prefer-string-replace-all": "off",
      "unicorn/prefer-code-point": "off",
      "promise/prefer-await-to-then": "off",
      "promise/prefer-await-to-callbacks": "off",
      "promise/avoid-new": "off",
      "oxc/no-async-await": "off",
      "no-unused-vars": [
        "error",
        {
          args: "all",
          argsIgnorePattern: "^_",
          caughtErrors: "all",
          caughtErrorsIgnorePattern: "^_",
          destructuredArrayIgnorePattern: "^_",
          ignoreRestSiblings: false,
        },
      ],
    },
    overrides: [
      {
        files: ["**/*.test.ts", "**/*.test.js", "**/*.spec.ts", "**/*.spec.js", "**/test/**/*"],
        plugins: ["import", "promise", "unicorn", "typescript", "node", "oxc", "vitest"],
        rules: {
          "no-console": "off",
          "no-alert": "off",
          "typescript/unbound-method": "off",
          "vitest/no-conditional-in-test": "error",
          "vitest/require-to-throw-message": "off",
        },
      },
    ],
    ignorePatterns: [
      "node_modules/**",
      "vendor/**",
      "tmp/**",
      "dist/**",
      "build/**",
      "coverage/**",
      ".ruby-lsp/**",
      "public/assets/**",
      "public/packs/**",
    ],
    options: {
      typeAware: true,
      typeCheck: true,
    },
  },
});
