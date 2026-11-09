# Guía de Instalación y Despliegue en Windows (`.exe`)

Esta guía describe cómo instalar, ejecutar y actualizar **PTI Packing AGV** en estaciones de trabajo Windows (Windows 10 y Windows 11 de 64 bits).

---

## 1. Requisitos del Sistema

- **Sistema Operativo:** Windows 10 o Windows 11 (64 bits).
- **Motor de Ventana Nativa:** Microsoft Edge (incluido por defecto en Windows 10/11) o Google Chrome.
- **Conectividad:**
  - **Con Internet:** Sincronización automática en tiempo real con Google Cloud Firestore (Catálogo Maestro Global, Historial y Usuarios).
  - **Sin Internet (Offline):** Operación continua con base de datos local en caché y librerías empaquetadas localmente (`jsbarcode.min.js`, SDKs de Firebase).
- **Impresora Térmica (Opcional):** Zebra ZT411 / ZT230 / ZD420 (203 DPI o 300 DPI) conectada por USB (Driver Windows ZDesigner, Web Serial o Zebra Browser Print) o red TCP/IP.

---

## 2. Opción A: Instalación Estándar mediante `PTI-Packing-AGV-Setup.exe` (Recomendada)

1. Ubique el archivo instalador:
   ```
   dist\PTI-Packing-AGV-Setup.exe
   ```
2. Haga doble clic sobre **`PTI-Packing-AGV-Setup.exe`**.
3. En la ventana del instalador **PTI Packing AGV — Instalador Oficial**:
   - Verifique la ruta de instalación predeterminada (`%LOCALAPPDATA%\Programs\PTI-Packing-AGV`).
   - Deje marcadas las casillas:
     - **Crear acceso directo en el Escritorio**
     - **Crear acceso directo en el Menú Inicio**
     - **Iniciar PTI Packing AGV al finalizar la instalación**
   - Haga clic en el botón **Instalar PTI Packing AGV**.
4. En menos de 3 segundos la instalación concluirá y la aplicación se abrirá en su propia ventana de escritorio.
5. A partir de ese momento podrá abrir el programa en cualquier momento desde el ícono **PTI Packing AGV** en su **Escritorio** o **Menú Inicio**.

### Desinstalación
- Puede desinstalar la aplicación ejecutando `Uninstall-PTI-Packing-AGV.exe` ubicado dentro de `%LOCALAPPDATA%\Programs\PTI-Packing-AGV`.

---

## 3. Opción B: Ejecución Directa / Portable (`PTI-Packing-AGV.exe`)

Si desea ejecutar el programa desde una memoria USB o carpeta compartida sin instalarlo:
1. Copie el contenido de la carpeta del proyecto (o ejecute directamente desde `dist\PTI-Packing-AGV.exe`).
2. Haga doble clic en **`PTI-Packing-AGV.exe`**.
3. El ejecutable levantará automáticamente el servidor local en `127.0.0.1:58420` y abrirá la ventana dedicada del sistema conservando todas las funcionalidades.

---

## 4. Configuración de Impresoras Zebra en Windows

### 4.1 Impresión por Driver de Windows (ZDesigner)
1. Instale el driver oficial **ZDesigner ZT411-203dpi ZPL** (o el modelo correspondiente) en Windows.
2. En **Propiedades de Impresora → Preferencias → Configuración de página**, verifique que el tamaño de papel esté configurado en **4.00" × 2.00" (101.6 mm × 50.8 mm)**.
3. En **PTI Packing AGV**, seleccione el modo **Driver Windows** y pulse **🖨️ Imprimir Etiqueta**.

### 4.2 Impresión Directa ZPL vía USB (Web Serial) o Zebra Browser Print
- **Web Serial:** Seleccione la impresora con conexión **Web Serial**, pulse **Conectar Puerto USB/COM** y elija su impresora Zebra de la lista del sistema.
- **Zebra Browser Print:** Asegúrese de que el servicio Zebra Browser Print esté activo en la bandeja del sistema (`127.0.0.1:9100`) y seleccione la impresora **Zebra Browser Print Directo**.

---

## 5. Cómo Recompilar el Instalador `.exe` tras Futuras Modificaciones

Si realiza cambios en `index.html` o en la documentación y desea regenerar tanto `dist\PTI-Packing-AGV.exe` como `dist\PTI-Packing-AGV-Setup.exe`:

1. Abra PowerShell en la raíz del proyecto (`PTI-AGROVISION`).
2. Ejecute el script de compilación:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\installer\build-installer.ps1
   ```
3. El script:
   - Generará el ícono multi-resolución `installer\app.ico` a partir de `logo.png`.
   - Compilará el lanzador de escritorio `dist\PTI-Packing-AGV.exe`.
   - Empaquetará todos los archivos del sistema en un archivo comprimido embebido y compilará el instalador gráfico `dist\PTI-Packing-AGV-Setup.exe`.
