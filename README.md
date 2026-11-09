# PTI PACKING AGV — Agrovision México

Sistema corporativo de emisión, validación de trazabilidad, calibración e impresión térmica de etiquetas **PTI (Produce Traceability Initiative)** estándar **4" × 2" (101.6 × 50.8 mm)** con código de barras **GS1-128**, **UPC-A**, **Code 128 de Lote** y **Voice Pick Code (CRC-16 ANSI)** en tiempo real.

---

## 📌 Características Principales

1. **Autenticación Corporativa y Perfiles Aislados por Usuario**
   - Pantalla de acceso **PTI Packing AGV — Agrovision México** con indicador de estado en línea.
   - Aislamiento operativo individual por usuario: cada usuario conserva su propio historial de etiquetas, selección operativa (lote, fecha, calibre, copias), calibración de diseño (`customLayout`) e impresora activa sin afectar a otros operadores conectados simultáneamente.
   - Cinco niveles de acceso configurables: **Administrador**, **Supervisor**, **Operador**, **Calidad** y **Personalizado** (con 6 permisos granulares).

2. **Catálogo Maestro Global en Tiempo Real (15 Campos)**
   - Los cambios realizados en la Base de Datos Maestra por un **Administrador** (o usuario con permiso `canManageDb`) se sincronizan automáticamente en tiempo real con todos los demás usuarios mediante Cloud Firestore (`pti_plant/catalog`).
   - Respaldo automático local (`localStorage`), importación/exportación JSON y restauración de semillas oficiales.

3. **Alarma y Restricción por Letra de UP en Trazabilidad**
   - Validación en tiempo real del **5.º carácter** del código de trazabilidad/lote (`A–G`) frente al código de **Unidad de Producción (UP)** del registro seleccionado en la base de datos:
     - `A` → **ARENA**
     - `B` → **LUPITA**
     - `C` → **AGUA BLANCA**
     - `D` → **SAN MARTIN**
     - `E` → **LOMA**
     - `F` → **REFUGIO**
     - `G` → **AYALA**
   - Cuando la letra del lote no coincide con la UP seleccionada, el sistema activa una **alarma sonora y visual**, muestra el botón de corrección rápida y bloquea la impresión/guardado hasta corregir la letra.

4. **Calibración y Visibilidad de Elementos (12 Controles)**
   - Control individual en tiempo real (vista previa, impresión Windows y código ZPL 203/300 DPI) para mostrar u ocultar:
     - `Mostrar UP en etiqueta`
     - `Mostrar Distribuidor`
     - `Código barras Lote`
     - `País de Origen`
     - `Línea separadora`
     - `Mostrar SIZE`
     - `Mostrar Pack Date`
     - `Exporting Country`
     - `Municipality / State`
     - `GGN`
     - `FDA`
     - `Exporter` (nombre y dirección del exportador)
   - Ajuste milimétrico de tamaños de fuente y coordenadas `X / Y` por bloque o desplazamiento global.

5. **Impresión Térmica Industrial Multi-Canal**
   - **Driver Windows (Spooler)**: Impresión directa de alta nitidez para impresoras Zebra ZT411 / ZDesigner.
   - **Web Serial API (USB / COM Directo)**: Envío directo de comandos ZPL II por puerto USB sin cuadro de diálogo.
   - **Zebra Browser Print**: Integración nativa con el servicio local Zebra (`127.0.0.1:9100`).
   - **Exportación `.ZPL`**: Descarga e inspección del código ZPL II en **203 DPI** y **300 DPI**.

6. **Modo Celular (Estación Compacta)**
   - Interfaz táctil optimizada para terminales portátiles, tabletas y teléfonos en piso de empaque.

---

## 📂 Estructura del Proyecto y Documentación

| Archivo / Carpeta | Descripción |
| :--- | :--- |
| [`index.html`](./index.html) | Aplicación completa (HTML5, CSS3, JavaScript, motor GS1-128/VPC, ZPL II y sincronización Firestore). |
| [`dist/PTI-Packing-AGV-Setup.exe`](./dist/PTI-Packing-AGV-Setup.exe) | **Instalador ejecutable para Windows (`.exe`)** con interfaz gráfica, creación de accesos directos y desinstalador. |
| [`dist/PTI-Packing-AGV.exe`](./dist/PTI-Packing-AGV.exe) | **Ejecutable autónomo/portable para Windows (`.exe`)** que inicia el servidor local seguro y abre la ventana de aplicación nativa conservando el 100% de las funciones. |
| [`installer/build-installer.ps1`](./installer/build-installer.ps1) | Script de compilación que genera `PTI-Packing-AGV.exe` y `PTI-Packing-AGV-Setup.exe` usando el compilador nativo de Microsoft .NET (`csc.exe`). |
| [`firebase.json`](./firebase.json) / [`firestore.rules`](./firestore.rules) | Configuración de despliegue en Firebase Hosting y reglas de seguridad de Cloud Firestore. |
| [`jsbarcode.min.js`](./jsbarcode.min.js) | Librería local para renderizado offline de códigos de barras GS1-128, UPC-A y Code 128. |
| [`firebase-app-compat.js`](./firebase-app-compat.js) / [`firebase-firestore-compat.js`](./firebase-firestore-compat.js) | SDKs locales de Firebase para operación sin dependencia de CDN externo. |
| [`docs/MANUAL_USUARIO_Y_OPERACION.md`](./docs/MANUAL_USUARIO_Y_OPERACION.md) | Manual completo de operación en piso de empaque, login, trazabilidad, alarmas UP y calibración. |
| [`docs/MANUAL_TECNICO_Y_ARQUITECTURA.md`](./docs/MANUAL_TECNICO_Y_ARQUITECTURA.md) | Documentación técnica de arquitectura, estructura de datos en Firestore, algoritmo CRC-16 y motor ZPL. |
| [`docs/GUIA_INSTALACION_WINDOWS.md`](./docs/GUIA_INSTALACION_WINDOWS.md) | Guía paso a paso de instalación del `.exe` en Windows, configuración de impresoras Zebra y compilación. |

---

## 🖥️ Instalación Rápida en Windows (`.exe`)

1. Ejecute **`dist\PTI-Packing-AGV-Setup.exe`**.
2. Haga clic en **"Instalar PTI Packing AGV"**.
3. El instalador copiará todos los módulos a `%LOCALAPPDATA%\Programs\PTI-Packing-AGV`, creará el acceso directo **PTI Packing AGV** en el **Escritorio** y en el **Menú Inicio**, y abrirá el programa automáticamente.
4. También puede ejecutar directamente **`dist\PTI-Packing-AGV.exe`** en modo portable desde la carpeta del proyecto.

---

## 🌐 Acceso Web en Nube

- **URL de Producción (Firebase Hosting):** `https://pti-agrovision-app.web.app`
