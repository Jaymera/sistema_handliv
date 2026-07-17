import type { Config } from "tailwindcss";

export default {
  content: ["./app/**/*.{ts,tsx}", "./src/**/*.{ts,tsx}"],
  theme: { extend: {} },
  plugins: [],
  darkMode: "media",
  presets: [require("nativewind/preset")],
} satisfies Config;