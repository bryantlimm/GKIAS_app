module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*",
    "/generated/**/*",
  ],
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  rules: {
    // Turn off the rules causing all the errors
    "quotes": "off",
    "max-len": "off",
    "object-curly-spacing": "off",
    "no-multi-spaces": "off",
    "require-jsdoc": "off",
    "import/no-unresolved": 0,
    "@typescript-eslint/no-explicit-any": "off",
  },
};
