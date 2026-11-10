import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";

// En desarrollo (`npm run dev`), lo de RyCitas se pide al backend local como si fuera el subdominio del negocio.
const rycitas = { target: "http://localhost:8000", changeOrigin: true, headers: { Host: "sonrisa-wari.localhost:8000" } };

export default defineConfig({
  plugins: [react()],
  server: {
    port: 8081,
    proxy: { "/public": rycitas, "/reservar": rycitas, "/rycitas.js": rycitas, "/media": rycitas, "/static": rycitas, "/c/": rycitas },
  },
});
