import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Dev server on 5173; the admin APIs live on the Go server (default :8080).
// The base URL is read at runtime from VITE_API_BASE (see .env.example).
export default defineConfig({
  plugins: [react()],
  server: { port: 5173, host: true },
})
