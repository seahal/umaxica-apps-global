import inertia from "@inertiajs/vite";
import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import RubyPlugin from "vite-plugin-ruby";
import { defineConfig } from "vite-plus";

export default defineConfig({
  plugins: [RubyPlugin(), tailwindcss(), inertia(), react()],
  staged: {
    "*": "vp test && vp check",
  },
  test: {
    root: "/home/global/workspace",
    include: ["test/**/*.{test,spec}.?(c|m)[jt]s?(x)"],
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
      reportsDirectory: "coverage/vite",
      reporter: ["text", "html", "lcov", "json-summary"],
      include: ["app/javascript/**/*.{js,ts,jsx,tsx}"],
      exclude: [
        "**/*.test.{js,ts,jsx,tsx}",
        "**/*.spec.{js,ts,jsx,tsx}",
        "**/node_modules/**",
        "**/vendor/**",
        "**/.ruby-lsp/**",
        "**/.pnpm-store/**",
        "**/tmp/**",
        "**/dist/**",
        "**/build/**",
        "**/coverage/**",
      ],
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
      "no-console": "warn",
      "no-debugger": "error",
      "no-alert": "warn",
      "no-duplicate-imports": "error",
      "import/no-duplicates": "error",
      curly: "warn",
      "prefer-destructuring": "warn",
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
        rules: {
          "no-console": "off",
          "no-alert": "off",
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
