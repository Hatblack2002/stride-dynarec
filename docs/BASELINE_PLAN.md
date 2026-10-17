# Plan de línea base de rendimiento

**Documento:** `docs/BASELINE_PLAN.md`
**Proyecto:** Stride Dynarec
**Fase:** 0 — Reconocimiento (plan) → 2 — Línea base (ejecución)
**Fecha:** 2026-10-18
**Base de código:** Box64 commit `27860e6aee72dd33c2588d081652d6e9becc1089`

---

## 1. Propósito

Definir, antes de medir, **qué** se va a medir, **cómo** se va a medir, y **qué hipótesis** se están evaluando. Este documento se escribe en la Fase 0 (reconocimiento) y se ejecuta en la Fase 2 (línea base), una vez completada la Fase 1 (compilación y prueba de funcionamiento).

No se mide sin un plan previo. No se optimiza sin una línea base previa.

## 2. Marco de capas y separación de responsabilidades

Antes de atribuir un coste al dynarec, hay que recordar que la ejecución de un juego de PC en Android pasa por capas distintas y **no equivalentes**:

```
                ┌─────────────────────────────────────────┐
                │  Capa 1: Traducción de CPU x86-64 → ARM64 │  ← Box64 / FEX-Emu
                ├─────────────────────────────────────────┤
                │  Capa 2: Compatibilidad de API Windows    │  ← Wine
                ├─────────────────────────────────────────┤
                │  Capa 3: Traducción gráfica D3D → Vulkan  │  ← DXVK
                ├─────────────────────────────────────────┤
                │  Capa 4: Controlador GPU (Adreno/Mali)    │  ← Driver propietario
                ├─────────────────────────────────────────┤
                │  Capa 5: Memoria, sincronización, syscalls│  ← Kernel Android
                └─────────────────────────────────────────┘
```

Stride Dynarec **solo investiga la Capa 1**. Un juego lento puede estar limitado por cualquiera de las otras cuatro. La línea base debe diseñarse para **aislar la Capa 1**.

## 3. Mapa del código verificado en Box64 (auditoría real)

Esta sección se redacta tras la lectura real del código fuente en `third_party/box64/`. **No contiene inventos.** Las rutas y funciones citadas se han confirmado en el commit fijado.

### 3.1 Punto de entrada al runtime

**Archivo:** `src/dynarec/dynarec.c`
**Función:** `EmuRun` (línea 193)

```
EmuRun(emu, use_dynarec=1, no_alt=0)
  └─> bucle mientras !emu->quit:
       ├─> SigSetJmp (manejo de señales)
       ├─> fastDBGetBlock(emu, R_RIP, create=1, is32bits)        ← despacho de bloque
       │     └─> si no existe o inválido → Run(emu, 1) intérprete
       │     └─> si existe y válido      → native_prolog(emu, block->block)
       └─> si emu->fork → EmuFork
```

`DynaRun` (línea 301) es un envoltorio fino que llama `EmuRun(emu, 1, 0)`. Es el punto de entrada habitual desde `core.c:1617`, `entrypoint.c:27`, `threads.c`, etc.

### 3.2 Despacho y validación de bloques

**Archivo:** `src/dynarec/dynablock.c`

| Función                  | Línea | Rol                                                                 |
|--------------------------|-------|---------------------------------------------------------------------|
| `DBGetBlock`             | 488   | Despacho público. Llama `internalDBGetBlock`, valida hash, gestiona `always_test`, hot pages. |
| `internalDBGetBlock`     | 376   | Si el bloque existe y es válido, lo devuelve. Si no, llama `FillBlock64`. Maneja `mutex_dyndump` y `BOX64ENV(dynarec_wait)`. |
| `InvalidDynablock`       | 80    | Marca un bloque como inválido (sin liberarlo necesariamente).       |
| `FreeDynablock`          | 227   | Libera un bloque definitivamente.                                   |
| `MarkRangeDynablock`     | 290   | Marca bloques en un rango de direcciones como needing-test.         |
| `MarkCRCRangeDynablock`  | 300   | Marca bloques para verificación de CRC.                             |
| `FreeRangeDynablock`     | 312   | Libera bloques en un rango.                                         |
| `FlushZombieDynablocks`  | 466   | Libera bloques pendientes de borrado diferido.                      |

### 3.3 Generación de bloques (pipeline de passes)

**Archivo:** `src/dynarec/dynarec_native.c`
**Función principal:** `FillBlock64` (línea 874)

Pipeline de 4 passes declaradas en líneas 414–417:

| Pass         | Rol                                                                                       |
|--------------|-------------------------------------------------------------------------------------------|
| `native_pass0` | Recorre instrucciones x64, calcula saltos, tamaño total del bloque, barreras.           |
| `native_pass1` | Análisis de flags, cálculo de necesidades de cada instrucción, hash del bloque.         |
| `native_pass2` | Asignación de registros nativos (RA), generación parcial de código ARM64.               |
| `native_pass3` | Emisión final de código ARM64, relocations, escritura del bloque ejecutable.            |

Implementaciones específicas ARM64 viven en `src/dynarec/arm64/dynarec_arm64_pass{0,1,2,3}.h` y los archivos `dynarec_arm64_*.c` por familia de opcodes (00, 0f, 66, d8-df, f0, f20f, f30f, etc.).

**Estructura de un bloque** (comentario en `FillBlock64` líneas 876–890):

```
0x0000..0x0007  : dynablock_t* : self
0x0008..8+4*n   : instrucciones nativas
A    .. A+8*n   : Table64 (constantes)
B    .. B+7     : dynablock_t* : self (parte de JmpNext)
B+8  .. B+8+m   : código nativo de jmpnext / epilog
B+J-8.. B+J-1   : dirección de jmpnext
B+J  .. B+J+sz  : instsize (longitudes por instrucción)
C    .. C+sz    : arch (info por instrucción, opcional)
```

### 3.4 Estructura `dynablock_t`

**Archivo:** `src/dynarec/dynablock_private.h`

Campos críticos para el análisis de costes:

| Campo                | Tipo         | Importancia para Stride Dynarec                                          |
|----------------------|--------------|--------------------------------------------------------------------------|
| `block`              | `void*`      | Puntero al código ARM64 ejecutable.                                      |
| `actual_block`       | `void*`      | Inicio real de la asignación.                                            |
| `x64_addr`           | `void*`      | Dirección x86-64 original.                                               |
| `x64_size`           | `uintptr_t`  | Tamaño en bytes del bloque x86-64.                                       |
| `native_size`        | `size_t`     | Tamaño del código ARM64 generado.                                        |
| `hash`               | `uint32_t`   | Hash X31 del contenido x86-64. Se compara en cada ejecución si `always_test`. |
| `done`               | `uint8_t`    | 1 cuando el bloque está completo y ejecutable.                          |
| `dirty`              | `uint8_t`    | 1 si necesita testearse en cuanto se crea.                              |
| `always_test`        | `uint8_t:2`  | 0=no testear, 1=NEVERCLEAN, 2=validación diferida.                       |
| `is32bits`           | `uint8_t:1`  | 1 si el bloque es de 32 bits.                                            |
| `autocrc`            | `uint8_t:1`  | Indica si el bloque se autocertifica con CRC.                           |
| `to_delete`          | `uint8_t:1`  | Marcado para borrado diferido.                                          |
| `instsize`           | `instsize_t*`| Mapa comprimido de longitudes.                                          |
| `jmpnext`            | `void*`      | Trampolín que ejecuta el test + salto.                                   |
| `table64`, `table64size` | —        | Tabla de constantes embebidas.                                           |
| `relocs`, `relocsize`| —            | Relocations para persistencia dynacache.                                 |

### 3.5 DynaCache (persistencia de bloques traducidos en disco)

**Archivos relevantes:**

| Archivo                                | Rol                                                            |
|----------------------------------------|----------------------------------------------------------------|
| `src/tools/dynacache.c`                | Lectura/escritura de caché en disco, límite de tamaño, prune.  |
| `src/dynarec/dynacache_reloc.c`        | Relocations para reconstruir punteros al recargar.             |
| `src/dynarec/dynacache_compress.c`     | Compresión zlib de los archivos de caché.                      |
| `src/include/dynacache_compress.h`     | Cabecera pública.                                              |

**Variables de entorno** (extraídas de `third_party/box64/docs/USAGE.md`):

| Variable                    | Valores / Default | Línea en USAGE.md |
|-----------------------------|-------------------|-------------------|
| `BOX64_DYNACACHE`           | 0 / **1 (default)** / 2 | 173              |
| `BOX64_DYNACACHE_FOLDER`    | `$XDG_CACHE_HOME/box64` o `$HOME/.cache/box64` (default) | 181 |
| `BOX64_DYNACACHE_LIMIT`     | MiB, **2048 (default)** | 187              |
| `BOX64_DYNACACHE_COMPRESS`  | 0 / **1 (default)** / 2 | 195              |
| `BOX64_DYNACACHE_MIN`       | KB, **30 (default)** | 203              |

**Comportamiento clave:**

- `BOX64_DYNACACHE=0` → deshabilita la persistencia (todos los bloques se generan en RAM y se pierden al cerrar el proceso).
- `BOX64_DYNACACHE=1` (default) → persiste y reutiliza. Genera nuevos archivos si hace falta.
- `BOX64_DYNACACHE=2` → solo lee, no genera. Útil para aislar el coste de "carga de caché" del coste de "traducción".

### 3.6 Hot pages (páginas modificadas activamente)

Box64 evita traducir bloques en páginas marcadas como "calientes" (modificadas activamente) para no invalidarlos en bucle. Las funciones `isInHotPage`, `checkInHotPage` y la variable `BOX64ENV(dynarec_dirty)` controlan este comportamiento.

### 3.7 Saltos inter-bloque (`jmpnext`)

Cada bloque tiene un trampolín `jmpnext` que permite:

1. Re-testear el hash del bloque antes de continuar (cuando `always_test=1` o `dirty=1`).
2. Saltar al siguiente bloque sin pasar por el despachador C.

El archivo `src/dynarec/arm64/arm64_jmpnext.c` y los `.S` asociados (`arm64_prolog.S`, `arm64_epilog.S`, `arm64_next.S`) implementan estas rutas en ensamblador ARM64.

## 4. Hipótesis de investigación (mapeadas a código real)

Las cinco hipótesis del pliego se concretan aquí con la ruta de código donde se investigarán.

### Hipótesis A — Trabajo redundante de traducción

> ¿Se traducen repetidamente bloques que podrían reutilizarse de manera segura?

**Rutas de código a auditar:**

- `dynablock.c:DBGetBlock` → el camino donde se valida `hash` con `X31_hash_code`. Si el hash falla, el bloque se invalida (`InvalidDynablock`) y se regenera (`internalDBGetBlock` con `create=1`).
- `dynablock.c:MarkRangeDynablock` y `MarkCRCRangeDynablock` → ver qué rutas llaman a estas funciones y con qué frecuencia. Una invalidación frecuente en una misma página es síntoma de hipótesis A.
- Hot pages (`isInHotPage`, `BOX64ENV(dynarec_dirty)`): si el mecanismo es demasiado conservador, bloques válidos se descartan.
- `BOX64_DYNACACHE` modos 0 vs 1 vs 2 → permite separar el coste de traducción (0) del coste de carga de caché (2).

**Métricas necesarias:**

- Tasa de invalidación (bloques invalidados / segundo).
- Tasa de re-traducción (llamadas a `FillBlock64` para una dirección ya traducida antes).
- Relación entre bloques ejecutados y bloques traducidos.

### Hipótesis B — Coste de generación de bloques

> ¿Existen costes innecesarios en la construcción, asignación, finalización o gestión de los bloques traducidos?

**Rutas de código a auditar:**

- `dynarec_native.c:FillBlock64` → el pipeline `BUILD_PASS0..BUILD_PASS3`. Ver si los passes recalculan información redundante.
- Asignación de memoria del bloque (`box_malloc`, `box_calloc` llamadas dentro del pipeline).
- `ResetTable64`, `kh_clear(nextset)`, `kh_clear(jumpaddr)` al inicio — ver si son costosos cuando el bloque es pequeño.
- Lógica de `SigSetJmp` alrededor del pass0 → tiene un coste aunque no se salte.

**Métricas necesarias:**

- Tiempo medio por pass0/pass1/pass2/pass3 (microbenchmarks con `clock_gettime(CLOCK_MONOTONIC)`).
- Número de instrucciones x64 por bloque (para normalizar el tiempo).
- Tamaño del código nativo generado (relación código x64 / código ARM64).

### Hipótesis C — Ineficiencias del despacho de ejecución

> ¿Hay costes medibles en el ciclo de búsqueda, selección, despacho y retorno de los bloques traducidos?

**Rutas de código a auditar:**

- `dynarec.c:EmuRun` → el bucle principal. Verificar el coste de `fastDBGetBlock` por llamada.
- `dynablock.c:DBGetBlock` → la validación de `getNeedTest(addr)` y `X31_hash_code`. Si se ejecuta en cada entrada a un bloque `dirty`, es coste directo.
- `arm64_prolog.S` y `arm64_epilog.S` → la transición C → ARM64 → C. Las stores/loads de registros en el prolog son costosas si el bloque es pequeño.
- `protectDBJumpTable` → mantienen una jump table por página; ver si el salto es directo o pasa por el trampolín.

**Métricas necesarias:**

- Número de despachos por segundo (bloques entrados).
- Tiempo medio de despacho (desde `fastDBGetBlock` hasta `native_prolog`).
- Relación entre tiempo de despacho y tiempo de ejecución del bloque.

### Hipótesis D — Presión de memoria

> ¿La asignación, el tamaño o la reutilización de las estructuras de traducción generan presión significativa sobre la memoria o la caché del procesador?

**Rutas de código a auditar:**

- `dynablock_t` tamaño (~120 bytes por bloque, ver `dynablock_private.h`).
- `instsize`, `arch`, `callrets`, `relocs`, `table64` → cada bloque tiene varios arrays auxiliares.
- `custommem.c` → gestiona la memoria ejecutable; ver la política de asignación y si hay fragmentación.
- L1I cache del Cortex-A77/A55 (32–64 KB por núcleo en SD865): bloques grandes pueden desalojar otros útiles.

**Métricas necesarias:**

- Memoria total usada por bloques (`/proc/self/status` VmRSS antes y después).
- Tamaño medio de bloque nativo.
- Cache misses de L1I (requiere `simpleperf` o `perf` — ver `INSTRUMENTATION.md`).

### Hipótesis E — Sincronización y corrección

> ¿Existen comprobaciones o barreras cuyo coste sea significativo en el escenario objetivo?

**Rutas de código a auditar:**

- `mutex_dyndump` en `internalDBGetBlock` → serializa la creación de bloques entre hilos.
- `BOX64ENV(dynarec_wait)` → si está activo, los hilos esperan; si no, devuelven NULL y van al intérprete.
- `pthread_sigmask` alrededor del FillBlock64 → bloquea señales temporalmente.
- `protectDB`, `protectDBJumpTable` → `mprotect` y escrituras en jump tables. Estas son barreras implícitas.
- `ClearCache` (línea 356) → llama a `__builtin___clear_cache` que en ARM64 se traduce a un `ic ivau` costoso.

**Regla de seguridad:** No se elimina ni debilita ninguna barrera sin análisis de semántica, pruebas de concurrencia y pruebas de corrección. Cualquier cambio propuesto en esta hipótesis requiere revisión adicional.

**Métricas necesarias:**

- Tiempo bloqueado en `mutex_dyndump` (si se instrumenta).
- Número de `ClearCache` por segundo.
- Número de `mprotect` por segundo (vía `strace` si está disponible).

## 5. Carga de prueba inicial (CPU-bound, no gráfica)

Para la Fase 2 se diseña una carga pequeña, repetible y con CPU conocido. **No se usa un juego completo como único instrumento de diagnóstico.** Un juego introduce demasiadas variables para aislar el coste del dynarec.

### 5.1 Carga de CPU candidata 1 — Bucle integer pur

Programa C mínimo que ejecuta un bucle de suma/AND/XOR controlado por un contador de iteraciones pasado como argumento. Compilado estáticamente para x86-64, ejecutado bajo Box64. Mide:

- Tiempo total de ejecución.
- Carga de CPU por hilo.
- Diferencia entre ejecución en frío (sin dynacache) y con dynacache reutilizada.

### 5.2 Carga de CPU candidata 2 — `dhrystone` o `coremark`

Benchmark clásico de CPU entera. Compilado estáticamente para x86-64, ejecutado bajo Box64. Permite comparar con resultados públicos de ARM64 nativo en el mismo SoC.

### 5.3 Carga de CPU candidata 3 — Microbench sintético propio

Un programa x86-64 que ejecuta deliberadamente un patrón de saltos conocido (saltos largos, llamadas anidadas, recursion) para forzar rutas específicas del dynarec. Útil para las hipótesis A y C.

### 5.4 Carga de referencia externa — `nbench`

Synthetic CPU benchmark disponible en repositorios. Ya se ha usado en evaluación de emuladores y permite comparación con números publicados.

### 5.5 Selección final

La carga final se selecciona en `BUILD_AND_SMOKE_TEST.md` (Fase 1) en función de:

- Disponibilidad de compilación estática x86-64 en el entorno de compilación que elija el responsable.
- Tiempo de ejecución por repetición (objetivo: 10–60 s para permitir varias repeticiones en una sesión).
- Sensibilidad al dynarec (debe variar entre `BOX64_DYNACACHE=0` y `BOX64_DYNACACHE=1`).

## 6. Metodología de medición

### 6.1 Variables a controlar

| Variable                  | Cómo se controla                                            |
|---------------------------|-------------------------------------------------------------|
| Temperatura inicial       | Esperar 5 min en idle antes de empezar. Medir con la herramienta seleccionada en `INSTRUMENTATION.md`. |
| Aplicaciones en 2º plano  | Cerrar todas las apps recientes. No notificaciones.         |
| Batería                   | Entre 50 % y 100 %, sin carga conectada (o con carga, mantenido constante). |
| Brillo de pantalla        | Mínimo, pantalla apagada si la carga no requiere UI.        |
| Modo de ahorro de energía | Desactivado, mantenido constante.                          |
| Caché de Box64            | Eliminada entre ejecuciones en frío; preservada entre ejecuciones con caché reutilizada. |

### 6.2 Variables a medir (si la herramienta lo permite)

| Variable                              | Herramienta candidata                          |
|---------------------------------------|------------------------------------------------|
| Duración total                        | `time` shell, `clock_gettime` interno           |
| Tiempo de CPU por hilo                | `getrusage(RUSAGE_THREAD)`, `/proc/self/stat`   |
| FPS y frametimes (solo para cargas gráficas) | `BOX64_LOG=1` o herramienta externa      |
| Temperatura                           | `termux-battery-status` (parcial), sensores disponibles sin root |
| Frecuencia de CPU                     | `cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq` |
| Memoria                               | `/proc/self/status`                             |
| Eventos del dynarec                   | `BOX64_DYNAREC_LOG=1` o instrumentación propia  |
| Invalidaciones de bloques             | Instrumentación propia en rama `stride/instr-01` |
| Errores                               | `logcat` y stderr de Box64                      |

### 6.3 Diseño experimental

Por cada combinación de configuración (carga × `BOX64_DYNACACHE`):

1. **Mínimo 3 repeticiones válidas.** Si la varianza observada es alta (>10 %), se hacen 5.
2. **Orden aleatorio** de las repeticiones para evitar sesgo por calentamiento progresivo.
3. **Registro completo** de cada repetición, no solo la media.
4. **Reporte de la mediana y el IQR**, no solo la media.
5. **Si una repetición es anómala** (caída, error, frecuencia estrangulada), se descarta y se documenta la causa.

### 6.4 Configuraciones a comparar en la línea base

| Configuración            | `BOX64_DYNACACHE` | Notas                                            |
|--------------------------|-------------------|--------------------------------------------------|
| L0 — Frío sin caché      | 0                 | Primera ejecución, sin caché persistente.        |
| L1 — Generación de caché | 1                 | Primera ejecución con caché habilitada.          |
| L2 — Caché reutilizada   | 2                 | Segunda ejecución, solo lectura de caché.        |
| L3 — Caché reutilizada   | 1                 | Tercera ejecución, caché ya generada.            |

L0 vs L1 → coste de escribir la caché.
L1 vs L2/L3 → beneficio de reutilizar la caché.
Si L2 ≈ L3, el coste de validación de caché es bajo.
Si L3 >> L2, hay trabajo redundante en L3.

## 7. Criterios de aceptación de la línea base

La línea base se considera **válida** si:

1. Las 3 repeticiones de cada configuración son reproducibles (IQR < 15 % de la mediana).
2. No se observan caídas ni errores en al menos 2 de cada 3 repeticiones.
3. La temperatura inicial se mantiene dentro de ±2 °C entre repeticiones de una misma configuración.
4. La diferencia entre L0 y L1/L2/L3 es detectable (mayor que la variabilidad observada). Si no lo es, el dynarec no es el cuello de botella para esa carga y se cambia de carga o se documenta la limitación.

## 8. Criterios para considerar una hipótesis "respaldada por evidencia"

Una hipótesis se considera respaldada solo si:

1. **Métrica identificada:** hay un número concreto que la describe (p. ej. "X invalidaciones/segundo").
2. **Magnitud significativa:** el valor medido es suficientemente grande para explicar una parte observable del coste total.
3. **Reproducible:** se obtiene en al menos 2 sesiones distintas, con dispositivo en condiciones controladas.
4. **Aislada:** se distingue del ruido de otras variables (térmicas, de caché, de GPU).
5. **No atribuible a otra capa:** se confirma que no es la GPU, ni Wine, ni DXVK, ni el driver.

Solo con esos cinco requisitos cumplidos se pasa a `docs/OPTIMIZATION_PROPOSAL_001.md` (Fase 4).

## 9. Lo que NO se hace en la Fase 2

- No se proponen cambios de código.
- No se compara Box64 con FEX-Emu todavía (eso es Fase 7).
- No se prueba con juegos completos (eso es Fase 6).
- No se elimina ninguna comprobación de seguridad.
- No se afirman métricas que la herramienta seleccionada no pueda obtener.

## 10. Próximos pasos

1. **Cerrar Fase 0:** el responsable devuelve la verificación del dispositivo (`docs/DEVICE_PROFILE.md` sección 5).
2. **Fase 1:** compilar Box64 en E-DEVICE siguiendo `docs/BUILD_AND_SMOKE_TEST.md` (a redactar tras recibir los datos del dispositivo).
3. **Fase 2:** ejecutar este plan de línea base.
4. **Fase 3:** seleccionar y validar la instrumentación en `docs/INSTRUMENTATION.md`.
5. **Fase 4:** redactar la primera propuesta de optimización con evidencia.
