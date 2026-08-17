import type { Config } from "tailwindcss";

export default {
  content: ["./app/**/*.{ts,tsx}", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: "#16D39A",
          dark: "#0EA27B",
          faint: "#16D39A1F",
        },
        night: {
          DEFAULT: "#0A1120",
          deep: "#070C16",
          800: "#0E1729",
          700: "#131F36",
          600: "#1C2B47",
          500: "#27395C",
        },
        ink: {
          DEFAULT: "#E9EFF9",
          soft: "#95A6C3",
          faint: "#5E7093",
        },
        up: "#16C784",
        down: "#EA3943",
        accent: "#4C8DFF",
      },
    },
  },
  plugins: [],
  darkMode: "media",
  presets: [require("nativewind/preset")],
} satisfies Config;
