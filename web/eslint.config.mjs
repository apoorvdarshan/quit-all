import js from "@eslint/js";
import globals from "globals";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["dist/**", ".wrangler/**", "node_modules/**"] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ["src/**/*.ts", "eslint.config.mjs"],
    languageOptions: { globals: globals.node },
  },
  {
    files: ["public/assets/**/*.js"],
    languageOptions: { globals: globals.browser, sourceType: "module" },
  },
);
