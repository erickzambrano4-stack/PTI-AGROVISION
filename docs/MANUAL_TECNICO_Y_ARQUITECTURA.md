# Manual Técnico y de Arquitectura — PTI Packing AGV

**Proyecto:** PTI Packing AGV (`pti-agrovision-app`)  
**Arquitectura:** Aplicación SPA Híbrida (Web + Ejecutable Nativo Windows `.exe` con Servidor HTTP Local)  
**Base de Datos en Nube:** Google Cloud Firestore + Almacenamiento Local Aislado por Usuario (`localStorage`)

---

## 1. Arquitectura General del Sistema

El sistema está diseñado bajo una arquitectura **Offline-First & Real-Time Cloud Sync**:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CLIENTE PTI PACKING AGV (Windows / Web)              │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌───────────────┐  │
│  │ Motor GS1-128 &      │  │ Motor ZPL II Nativo  │  │ Renderizador  │  │
│  │ Voice Pick (CRC-16)  │  │ (203 DPI / 300 DPI)  │  │ SVG / Spooler │  │
│  └──────────┬───────────┘  └──────────┬───────────┘  └───────┬───────┘  │
│             └─────────────────────────┼──────────────────────┘          │
│                                       ▼                                 │
│               Capa de Persistencia Aislada por Usuario                  │
│          (localStorage con clave sufijada `__usr_{username}`)           │
└───────────────────┬───────────────────────────────┬─────────────────────┘
                    │                               │
                    ▼                               ▼
     ┌─────────────────────────────┐ ┌─────────────────────────────┐
     │   Google Cloud Firestore    │ │  Subsistema de Impresión    │
     │  • pti_plant/catalog        │ │  • Windows Driver Spooler   │
     │  • pti_users/{username}     │ │  • Web Serial API (USB/COM) │
     │  • pti_history/{docId}      │ │  • Zebra Browser Print 9100 │
     │  • pti_users_auth/{userId}  │ │  • Descarga directa .ZPL    │
     └─────────────────────────────┘ └─────────────────────────────┘
```

---

## 2. Modelo de Datos y Sincronización en Cloud Firestore

### 2.1 Colecciones en Cloud Firestore

1. **`pti_plant/catalog` (Catálogo Maestro Global)**
   - Almacena el arreglo maestro `records` con los 15 campos oficiales de cada producto/UP.
   - **Escritura:** Cuando un usuario con permiso `canManageDb` (o rol `Administrador`) agrega, edita, importa o elimina un registro en `saveDb()`, se invoca `pushMasterCatalog(true)`.
   - **Lectura en Tiempo Real:** Todos los usuarios conectados mantienen activa la suscripción `listenToMasterCatalog()` (`onSnapshot`), actualizando instantáneamente sus selectores, tabla de catálogo y vista previa sin recargar la página.

2. **`pti_users/{username}` (Preferencias y Estado Operativo por Usuario)**
   - Almacena de forma aislada para cada usuario:
     - `preferences.layout`: Configuración completa de calibración y visibilidad (`customLayout`).
     - `preferences.zebra`: Parámetros de impresora térmica (`zebraConfig`) e impresora activa (`activePrinterId`).
     - `preferences.operation`: Selección actual (`activeRecordId`, `lote`, `packdate`, `size`, `copies`).
   - Garantiza que ningún cambio operativo o de diseño hecho por un usuario afecte a otro usuario.

3. **`pti_history/{entryId}` (Historial Sincronizado por Usuario)**
   - Cada registro emitido o guardado manualmente almacena:
     - `id`, `fechaHora`, `cultivo`, `formato`, `gtin`, `upc`, `lote`, `packdate`, `size`, `unidad`, `codigoUP`, `vpc`, `copias`, `createdBy`, `createdAtMs`.
   - La suscripción en tiempo real filtra los registros donde `createdBy` coincide con el usuario autenticado actual (`getCurrentUsernameKey()`), manteniendo sincronizado su historial entre sesiones y dispositivos.

4. **`pti_users_auth/{userId}` (Usuarios, Roles y Permisos)**
   - Almacena las cuentas de usuario, roles (`Administrador`, `Supervisor`, `Operador`, `Calidad`, `Personalizado`), estado activo, indicador `mustChangePassword` y el objeto `permissions` (`canPrint`, `canEditLot`, `canEditLayout`, `canManageDb`, `canManageZebra`, `canManageUsers`).

---

## 3. Especificación de Algoritmos PTI y GS1-128

### 3.1 Estructura de la Cadena GS1-128
El código de barras superior utiliza la simbología **GS1-128 (Code 128 Subset C/B con FNC1)** con tres Identificadores de Aplicación (AI):
- **AI `(01)`**: GTIN de 14 dígitos (numérico).
- **AI `(13)`**: Fecha de empaque (`Pack Date`) en formato `YYMMDD` (6 dígitos).
- **AI `(10)`**: Código de Lote / Trazabilidad alfanumérico de longitud variable (estándar Agrovision: 13 caracteres, donde el índice `4` —5.º carácter— representa el código de Unidad de Producción `A–G`).

### 3.2 Algoritmo de Voice Pick Code (CRC-16 ANSI)
El **Voice Pick Code (VPC)** de 4 dígitos (2 dígitos pequeños + 2 dígitos grandes) se calcula conforme al estándar oficial **Produce Traceability Initiative (PTI)**:
1. Se concatena en texto plano sin paréntesis ni espacios:
   ```
   PlainText = GTIN(14 dígitos) + PackDate(YYMMDD, opcional según estándar PTI) + Lote(Mayúsculas)
   ```
2. Se aplica el polinomio **CRC-16 ANSI (`0xA001` reflejado, valor inicial `0x0000`)** byte a byte sobre los caracteres ASCII.
3. El resultado entero de 16 bits se reduce módulo `10000` (`crc % 10000`) y se formatea a 4 dígitos con ceros a la izquierda:
   - **Dígitos pequeños (`small`)**: primeros 2 dígitos (`00–99`).
   - **Dígitos grandes (`large`)**: últimos 2 dígitos (`00–99`).

### 3.3 Validación de Letra de UP en Trazabilidad (`validateLoteFormat`)
La validación del código de lote verifica:
1. Que el lote no esté vacío.
2. Si el lote tiene al menos 5 caracteres y el registro seleccionado tiene una letra oficial de UP (`A–G`), extrae `lotChar = clean.charAt(4)` y verifica:
   - Que `lotChar` sea una letra de campo válida (`A–G`).
   - Que `lotChar === expected.letra` (coincidencia exacta con la UP seleccionada en la base de datos).
3. En caso de discrepancia, retorna `{ valid: false, reason: 'up_mismatch', expectedLetter, foundLetter }`, disparando la alarma visual/sonora (`triggerUpMismatchAlarm`) y bloqueando la emisión.

---

## 4. Motor Generador ZPL II (`generateZPL`)

La función `generateZPL()` traduce dinámicamente el estado actual y las preferencias de calibración (`customLayout` y `zebraConfig`) en código nativo **ZPL II** para cabezales de **203 DPI (8 dots/mm, ancho 812 dots × alto 406 dots)** y **300 DPI (12 dots/mm, ancho 1200 dots × alto 600 dots)**:

- **Parámetros de Hardware:**
  - Oscuridad térmica: `~SD00` a `~SD30`
  - Velocidad de impresión: `^PR{speed},{speed}`
  - Desplazamiento horizontal/vertical: `^LS{dots}` y `^LT{dots}` (combinando la calibración de hardware Zebra con `globalX` / `globalY`)
  - Orientación: `^PON` (normal) o `^POI` (invertida)
  - Tipo de sensor: `^MNY` (Gap/Muesca), `^MNM` (Marca negra), `^MNN` (Continuo)
  - Cantidad de copias: `^PQ{copies},0,1,Y`
- **Visibilidad Condicional en ZPL:**
  - Cada uno de los 12 controles de visibilidad (`showUP`, `showDist`, `showLotBar`, `showOrigin`, `showTitleLine`, `showSize`, `showPackDate`, `showCountry`, `showMuni`, `showGgn`, `showFda`, `showExporter`) incluye u omite dinámicamente sus respectivos comandos `^FO...^FS` tanto en 203 DPI como en 300 DPI.

---

## 5. Arquitectura del Ejecutable Windows (`.exe`)

El proyecto incluye dos ejecutables nativos compilados con Microsoft .NET Framework (`csc.exe`):

1. **`dist\PTI-Packing-AGV.exe` (Lanzador de Aplicación de Escritorio)**
   - Inicia un servidor HTTP local seguro en `http://127.0.0.1:58420` (con selección automática de puerto alternativo si estuviera ocupado) sirviendo los activos locales empaquetados (`index.html`, `jsbarcode.min.js`, `firebase-app-compat.js`, `firebase-firestore-compat.js`, `logo.png`).
   - Abre automáticamente una ventana nativa dedicada (`--app=http://127.0.0.1:58420`) en Microsoft Edge o Google Chrome con perfil dedicado, lo que habilita:
     - **Contexto Seguro (`Secure Context`)** indispensable para **Web Serial API** (impresión USB directa a Zebra) y portapapeles.
     - **Persistencia permanente** de `localStorage` e IndexedDB en el origen fijo `http://127.0.0.1:58420`.
     - **Sincronización Cloud Firestore** en tiempo real cuando hay conexión a internet y operación 100% funcional en modo offline.
   - Finaliza automáticamente el servidor en segundo plano cuando el usuario cierra la ventana del programa.

2. **`dist\PTI-Packing-AGV-Setup.exe` (Instalador Gráfico para Windows)**
   - Empaqueta dentro de un único archivo `.exe` auto-extraíble la aplicación completa, las librerías offline, el ícono corporativo y la documentación.
   - Muestra un asistente gráfico de instalación que:
     - Instala los archivos en `%LOCALAPPDATA%\Programs\PTI-Packing-AGV` (no requiere permisos de administrador local de Windows).
     - Crea accesos directos con el ícono de Agrovision en el **Escritorio** y en el **Menú Inicio**.
     - Registra el desinstalador (`Uninstall-PTI-Packing-AGV.exe`).
     - Ofrece iniciar **PTI Packing AGV** inmediatamente al finalizar.
