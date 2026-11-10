// RNF-03: disponibilidad con p95 < 300 ms y 20 usuarios simultáneos.
//   k6 run -e BASE=http://localhost:8000 -e SLUG=sonrisa-wari -e MOTIVO=limpieza-dental scripts/carga.js
import http from "k6/http";
import { check, sleep } from "k6";

const BASE = __ENV.BASE || "http://localhost:8000";
const SLUG = __ENV.SLUG || "sonrisa-wari";
const MOTIVO = __ENV.MOTIVO || "limpieza-dental";

export const options = {
  vus: 20,
  duration: "30s",
  thresholds: {
    "http_req_duration{tipo:disponibilidad}": ["p(95)<300"],
    http_req_failed: ["rate<0.01"],
  },
};

export default function () {
  const r = http.get(`${BASE}/public/v1/${SLUG}/disponibilidad?motivo=${MOTIVO}`, { tags: { tipo: "disponibilidad" } });
  check(r, { "responde 200": (x) => x.status === 200, "trae días": (x) => x.json("dias").length > 0 });
  sleep(1);
}
