import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Route, Routes } from "react-router-dom";
import "./styles.css";
import {
  Articulo,
  Consejos,
  Contacto,
  Inicio,
  NoEncontrada,
  Nosotros,
  PreguntasFrecuentes,
  TratamientoDetalle,
  Tratamientos,
  Urgencias,
} from "./paginas";

// /reservar/, /c/ y /privacidad/ no están aquí: las sirve RyCitas y ganan siempre al sitio.
createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Inicio />} />
        <Route path="/tratamientos" element={<Tratamientos />} />
        <Route path="/tratamientos/:slug" element={<TratamientoDetalle />} />
        <Route path="/nosotros" element={<Nosotros />} />
        <Route path="/preguntas-frecuentes" element={<PreguntasFrecuentes />} />
        <Route path="/consejos" element={<Consejos />} />
        <Route path="/consejos/:slug" element={<Articulo />} />
        <Route path="/contacto" element={<Contacto />} />
        <Route path="/urgencias" element={<Urgencias />} />
        <Route path="*" element={<NoEncontrada />} />
      </Routes>
    </BrowserRouter>
  </StrictMode>,
);
