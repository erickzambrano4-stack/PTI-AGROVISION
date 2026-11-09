# Manual de Usuario y Operación — PTI Packing AGV

**Sistema:** PTI Packing AGV — Agrovision México  
**Formato Estándar:** Etiqueta térmica PTI 4" × 2" (101.6 × 50.8 mm)  
**Estándar de Codificación:** GS1-128 + UPC-A + Code 128 + Voice Pick Code (CRC-16 ANSI)

---

## 1. Inicio de Sesión y Control de Acceso

Al abrir **PTI Packing AGV**, se presenta la pantalla de autenticación corporativa:

1. Verifique el indicador superior derecho **En Línea** (confirma sincronización en tiempo real con la nube de Agrovision).
2. Ingrese su **Usuario o Correo Electrónico** en el primer campo.
3. Ingrese su **Contraseña de Acceso** en el segundo campo (puede pulsar el ícono del ojo para mostrar/ocultar la contraseña).
4. Haga clic en **Acceder al Sistema**.

### 1.1 Perfiles y Permisos por Rol

| Rol | Imprimir Etiquetas | Modificar Lote / Fecha / Calibre | Calibración y Diseño | Base de Datos Maestra | Configurar Hardware Zebra | Administrar Usuarios |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Administrador** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Supervisor** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Operador** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Calidad** | ❌ (Solo consulta) | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Personalizado** | Configurable | Configurable | Configurable | Configurable | Configurable | Configurable |

> **Nota sobre Aislamiento por Usuario:** Todos los cambios operativos que realice un usuario (selección de producto, lote, fecha de empaque, calibre, número de copias, calibración de visibilidad y su historial de etiquetas guardadas) se almacenan **individualmente para ese usuario**, sin alterar la sesión ni los valores de otros usuarios.

---

## 2. Emisión de Etiquetas PTI (Vista Principal)

En la pestaña **🏷️ Etiqueta e Impresión**, siga estos pasos:

### Paso 1: Seleccionar Registro del Catálogo Maestro
- En el selector **1. Seleccionar registro de la base de datos (Catálogo Maestro)**, elija la combinación requerida de **Unidad de Producción (UP)**, **Cultivo** y **Formato / Presentación**.
- Debajo del selector verá el resumen automático con el **GTIN (14 dígitos)**, **UPC (12 dígitos)**, **GGN**, **FDA** y **UP**.

### Paso 2: Verificar Fecha de Empaque (`Pack Date`) y Calibre (`SIZE`)
- **Fecha de Empaque (`Pack Date`):** Se inicializa automáticamente con la fecha actual del sistema. Al cambiarla, se actualizan de inmediato:
  - El texto `Pack Date` en formato estadounidense (`MM/DD/YYYY`).
  - El identificador de aplicación `(13)YYMMDD` dentro del código de barras superior **GS1-128**.
  - El **Voice Pick Code** de 4 dígitos.
- **Calibre (`SIZE`):** Seleccione o escriba el calibre (`R1`, `JBO`, `XL`, `L`, etc.).

### Paso 3: Ingresar el Código de Lote / Trazabilidad
- El campo **Lote / Trazabilidad** acepta un código alfanumérico de **13 caracteres** (por ejemplo: `6B13B09118058`).
- También puede utilizar los **Botones Rápidos de Campo (`A` a `G`)** para cambiar con un clic la Unidad de Producción activa y actualizar automáticamente la letra en la posición 5 del lote.

---

## 3. Alarma y Restricción por Letra de UP en Trazabilidad

Para evitar errores de trazabilidad en empaque, el sistema valida en tiempo real que la **letra de Unidad de Producción (5.º carácter del código de lote)** coincida con la **UP seleccionada en la Base de Datos Maestra**:

| Letra Oficial | Unidad de Producción (UP) |
| :---: | :--- |
| **A** | ARENA |
| **B** | LUPITA |
| **C** | AGUA BLANCA |
| **D** | SAN MARTIN |
| **E** | LOMA |
| **F** | REFUGIO |
| **G** | AYALA |

### ¿Qué ocurre cuando la letra del lote NO coincide con la UP seleccionada?
1. **Alarma Sonora y Visual:** El sistema emite un aviso acústico de alerta, el borde del campo de trazabilidad parpadea en rojo y se despliega un banner de alarma indicando qué letra tiene el lote y qué letra corresponde a la UP seleccionada.
2. **Corrección en 1 Clic:** El banner de alarma incluye el botón **🔧 Corregir letra a "[Letra]" en el lote**, que corrige automáticamente el 5.º carácter sin perder el resto de la trazabilidad.
3. **Bloqueo Preventivo de Impresión y Guardado:** Mientras exista discrepancia entre la letra del lote y la UP seleccionada, el sistema bloquea la impresión y el guardado en el historial para garantizar cero etiquetas con UP cruzada.

---

## 4. Ajustes y Calibración Manual (Visibilidad y Posición)

Despliegue el panel **⚙️ Ajustes y Calibración Manual (Tamaño y Posición)** para personalizar el diseño de la etiqueta.

### 4.1 Visibilidad de Elementos (`👁️ Visibilidad de elementos`)
Puede activar o desactivar en tiempo real cualquiera de los **12 elementos** de la etiqueta (afecta tanto a la vista previa como a la impresión por Windows y al código ZPL Zebra):

1. **Mostrar UP en etiqueta** (oculto por defecto; muestra el nombre corto del rancho y su letra, ej. `LUPITA [B]`).
2. **Mostrar Distribuidor** (`Distributed By ...`).
3. **Código barras Lote** (código de barras Code 128 inferior izquierdo).
4. **País de Origen** (`PRODUCT OF MEXICO` o texto personalizado).
5. **Línea separadora** (línea horizontal bajo el subtítulo del formato).
6. **Mostrar SIZE** (recuadro de calibre en la columna derecha).
7. **Mostrar Pack Date** (recuadro de fecha de empaque en la columna derecha).
8. **Exporting Country** (`Exporting Country: Mexico`).
9. **Municipality / State** (`Municipality / State: ...`).
10. **GGN** (`GGN: ...`).
11. **FDA** (`FDA: ...`).
12. **Exporter** (nombre de la empresa exportadora y su dirección fiscal).

### 4.2 Tamaños de Fuente y Desplazamiento X / Y
- Ajuste con controles deslizantes el tamaño de fuente de: **Título Producto**, **Subtítulo Formato**, **Texto Trazabilidad/GGN**, **Fecha Empaque**, **Tamaño SIZE**, **Voice Pick Grande/Chico** y **País de Origen**.
- Utilice los controles de desplazamiento **Horizontal (X)** y **Vertical (Y)** para calibrar la posición individual de cada bloque o el **Desplazamiento Global** de toda la etiqueta.
- Haga clic en **💾 Guardar Diseño** para conservar su configuración personal en su perfil de usuario.

---

## 5. Historial Sincronizado por Usuario

En la tarjeta **📜 Historial de Etiquetas Emitidas / Guardadas**:
- Pulse **💾 Guardar PTI en Historial** para registrar la configuración actual (producto, lote, fecha de empaque, calibre y copias) o imprima una etiqueta (se registra automáticamente).
- El historial se sincroniza en tiempo real con Cloud Firestore para su usuario.
- Cada registro del historial cuenta con:
  - **🔄 Cargar:** Restaura todos los datos de esa etiqueta en el editor.
  - **🖨️ Reimprimir:** Carga y envía inmediatamente la etiqueta a impresión.
  - **🗑️ Eliminar:** Borra el registro de su historial.

---

## 6. Administración de Base de Datos Maestra (Administradores)

En la pestaña **📂 Base de Datos (15 Campos)**:
- Los usuarios con rol **Administrador** (o permiso de gestión de base de datos) pueden crear, editar, duplicar o eliminar registros del catálogo maestro.
- Al guardar cualquier cambio en la Base de Datos Maestra, **el catálogo se actualiza automáticamente en tiempo real para todos los demás usuarios** conectados al sistema.

---

## 7. Modo Celular (Estación Compacta)

Haga clic en el botón superior **📱 Modo Celular** (o acceda desde un dispositivo móvil) para abrir la interfaz compacta de 3 pestañas:
1. **🏷️ Datos PTI:** Selección rápida de campo (`A–G`), catálogo, lote con alarma UP en vivo, calibre y fecha.
2. **🖨️ Impresión:** Vista previa a escala exacta 4" × 2", Voice Pick Code destacado, selector de copias (`−` / `+`) y botón táctil gigante **IMPRIMIR ETIQUETA**.
3. **⚙️ Zebra:** Selección de impresora activa, prueba de impresión y ajuste rápido de oscuridad (`~SD`) y velocidad (`^PR`).

---

## 8. Sistema de Licencias por Clave de Activación y Límite de Cupos

El sistema cuenta con protección de licencias en tiempo real sincronizada con Cloud Firestore para controlar qué equipos están autorizados a operar **PTI Packing AGV**:

1. **Identificación Única de Hardware (`Hardware ID`):**
   - En la versión de escritorio Windows (`.exe`), el sistema obtiene automáticamente la huella criptográfica del equipo (`MachineGuid` de Windows + nombre de host) con formato `AGV-XXXX-XXXX`.
2. **Activación en Nuevos Equipos:**
   - Al abrir el programa en una computadora nueva no registrada, se muestra la pantalla **🔒 Activación de Licencia · PTI Packing AGV**.
   - El operador o soporte técnico ingresa una **Clave de Activación** válida (por ejemplo `AGV-2026-MASTER-01` o una clave generada por el Administrador) y asigna el nombre de la estación (ej. *Empaque Línea 2*).
3. **Panel de Administración de Licencias y Cupos (`👥 Usuarios y Permisos`):**
   - **Ampliar o Reducir Cupo Global:** El Administrador puede modificar en cualquier momento el **Límite Máximo de Equipos Permitidos** (con botones rápidos `➕ +1 Cupo` y `➕ +5 Cupos` o ingresando el número deseado).
   - **Generador de Claves de Activación:** Permite emitir claves nuevas con etiqueta de área/estación, número de cupos (`1` o multiequipo) y fecha de vigencia opcional (o permanentes).
   - **Control de Equipos en Tiempo Real:** Muestra todos los equipos registrados con su `Hardware ID`, nombre de PC, usuario en sesión y última conexión. Permite **🚫 Bloquear PC** o **🗑️ Liberar Cupo** con un clic para transferir la licencia a otra computadora de inmediato.
   - **Desbloqueo de Emergencia Admin:** Si el límite de cupos está lleno al intentar abrir el programa en un equipo nuevo, el Administrador puede desplegar la opción **🛡️ ¿Eres Administrador?** directamente en la ventana de activación, ingresar sus credenciales y ampliar `+1 cupo` automáticamente.
