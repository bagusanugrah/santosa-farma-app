/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#ecfeff',
          100: '#cffafe',
          200: '#a5f3fc',
          300: '#67e8f9',
          400: '#4ab8c4', // Official Instagram Logo Cyan
          500: '#22b0be',
          600: '#0891b2', // Primary Interactive Cyan/Teal
          700: '#0e7490',
          800: '#155e75',
          900: '#164e63',
          950: '#083344',
          navy: '#1e3a5f', // Official Logo Navy
        },
      },
    },
  },
  plugins: [],
}
