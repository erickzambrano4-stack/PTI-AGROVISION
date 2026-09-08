# PTI Label Studio

Sistema integral para emisión y calibración de etiquetas de trazabilidad PTI (Produce Traceability Initiative) estándar 4" × 2".

## 🚀 Características
- **Generación GS1-128:** Códigos de barra con Voice Pick Code (VPC) dinámico calculado mediante algoritmo CRC-16 ANSI.
- **Base de Datos Maestra:** Catálogo oficial de productos, formatos, UP (Unidad de Producción), GGN y UPC/GTIN.
- **Impresión Térmica Zebra:** Conectividad directa con impresoras Zebra (ZPL 203 y 300 DPI) vía Zebra Browser Print, Driver Windows Spooler y Web Serial.
- **Modo Celular (Estación Compacta):** Interfaz táctil adaptada para terminales móviles y estaciones de campo.
- **Identidad Corporativa:** Soporte para logotipos y títulos personalizados por planta/empaque.
- **Control de Acceso:** Roles y permisos configurables por usuario.

## 📦 Estructura del Proyecto
- index.html: Aplicación SPA completa (HTML5, CSS3 moderno, JavaScript vanilla).
- jsbarcode.min.js: Librería local para renderizado offline de códigos de barras.
