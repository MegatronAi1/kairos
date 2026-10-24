/** Tailwind wired to generated design tokens (design/tokens.json). No raw colours in components. */
module.exports = {
  presets: [require("./src/styles/tokens.preset.cjs")],
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: { extend: {} },
  plugins: [],
};
