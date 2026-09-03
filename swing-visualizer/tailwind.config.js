/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        turf: {
          400: '#53e38d',
          500: '#25c774',
          600: '#18a65c',
        },
        ink: {
          950: '#07110d',
          900: '#0b1712',
          850: '#102019',
          800: '#15271f',
        },
      },
      boxShadow: {
        panel: '0 24px 70px rgba(0, 0, 0, 0.28)',
        glow: '0 0 32px rgba(37, 199, 116, 0.18)',
      },
    },
  },
  plugins: [],
}
