# Perfil del dispositivo

Fase 0 — Reconocimiento. 2026-10-18.

El agente no tiene acceso al dispositivo. Tres categorías de datos:

- `[DECLARADO]` — por el responsable.
- `[PENDIENTE]` — pendiente de verificar con `scripts/device_profile_probe.sh`.
- `[REFERENCIA]` — fuente pública, no verificada para la unidad concreta.

El Galaxy S20 FE tiene al menos dos variantes con SoC distinto (SD865 vs Exynos 990). Esto cambia las flags de compilación de Box64 (`-D SD865=1` vs `-D ARM64=1`).

## 1. Datos declarados

| Campo                | Valor                                | Estado        |
|----------------------|--------------------------------------|---------------|
| Modelo comercial     | Samsung Galaxy S20 FE                | `[DECLARADO]` |
| Memoria RAM          | 6 GB                                 | `[DECLARADO]` |
| Arquitectura destino | ARM64                                | `[DECLARADO]` |
| Sistema operativo    | Android                              | `[DECLARADO]` |
| Entorno de terminal  | Termux (previsto)                    | `[DECLARADO]` |
| Acceso root          | No disponible                        | `[DECLARADO]` |
| Restricción operativa| Desarrollo desde el propio teléfono  | `[DECLARADO]` |

## 3. Datos pendientes de verificación en el dispositivo

Estos datos **deben obtenerse** ejecutando los comandos de la sección 5 desde Termux. Hasta entonces, el perfil del dispositivo está incompleto y no se puede garantizar que las opciones de compilación sean correctas.

| Campo                                | Comando sugerido                                  | Estado        |
|--------------------------------------|---------------------------------------------------|---------------|
| Modelo exacto (SM-G781B/U/N, etc.)   | `getprop ro.product.model`                        | `[PENDIENTE]` |
| Variante regional                    | `getprop ro.boot.hwc_model` / `ro.product.name`   | `[PENDIENTE]` |
| SoC real (Exynos 990 vs SD865)       | `getprop ro.soc.manufacturer` + `ro.soc.model`    | `[PENDIENTE]` |
| GPU y controlador                    | `dumpsys SurfaceFlinger \| grep GLES` (parcial)   | `[PENDIENTE]` |
| Versión de Android                   | `getprop ro.build.version.release`                | `[PENDIENTE]` |
| Nivel de API                         | `getprop ro.build.version.sdk`                    | `[PENDIENTE]` |
| RAM total y disponible               | `cat /proc/meminfo \| head -3`                    | `[PENDIENTE]` |
| Almacenamiento libre                 | `df -h $HOME`                                     | `[PENDIENTE]` |
| Número de núcleos y freq. máximas    | `ls /sys/devices/system/cpu/` + `cat …/cpufreq/cpuinfo_max_freq` | `[PENDIENTE]` |
| Versión de Termux instalada          | `termux-info`                                     | `[PENDIENTE]` |
| Versión de clang en Termux           | `clang --version`                                 | `[PENDIENTE]` |
| Versiones Box64/Wine/DXVK instaladas | `box64 --version`, etc. (si ya instalados)        | `[PENDIENTE]` |

## 4. Información de referencia pública (no verificada para la unidad concreta)

### 4.1 Variantes conocidas del Galaxy S20 FE

Según información pública de Samsung y de la comunidad (referencia: página oficial de soporte de Samsung y Wiki de XDA Developers, consultar enlaces al final):

| Variante       | Modelo        | SoC               | GPU                  | Regiones principales       |
|----------------|---------------|-------------------|----------------------|----------------------------|
| Global (4G/LTE)| SM-G780F      | Snapdragon 865    | Adreno 650           | Europa, Asia, LATAM        |
| Global (5G)    | SM-G781B      | Exynos 990         | Mali-G77 MP11        | Europa, Asia               |
| USA (5G)       | SM-G781U      | Snapdragon 865    | Adreno 650           | EE. UU. (carrier-unlocked) |
| USA (5G, VM)   | SM-G781U1     | Snapdragon 865    | Adreno 650           | EE. UU. (factory unlocked) |
| Corea (5G)     | SM-G781N      | Exynos 990         | Mali-G77 MP11        | Corea del Sur              |
| Canadá (5G)    | SM-G781W      | Snapdragon 865    | Adreno 650           | Canadá                     |

**Implicación para Box64:** el proyecto CMake de Box64 incluye una variante `SD865` explícita (ver `CMakeLists.txt:22` y bloque `elseif(SD865)` en línea 213). Si el dispositivo es SM-G780F, SM-G781U/U1/W, esta variante es la opción correcta. **No existe variante específica para Exynos 990**, por lo que para la variante SM-G781B/N se debe usar la opción genérica `ARM64=1`.

Fuentes:
- https://www.samsung.com/global/galaxy/galaxy-s20-fe/
- https://www.gsmarena.com/samsung_galaxy_s20_fe-10370.php
- https://www.xda-developers.com/samsung-galaxy-s20-fe/

> **Estas URLs se citan como referencia pública y deben contrastarse con `getprop` en el dispositivo.** El agente no valida la exactitud de los datos de terceros sobre el dispositivo concreto.

### 4.2 Soporte de Box64 para Snapdragon 865

| Opción CMake | Línea en `CMakeLists.txt` | Estado                                          |
|--------------|---------------------------|-------------------------------------------------|
| `SD865=1`    | 22 (option), 213–215 (if) | Soporte específico, define `-DSD865`            |

Esto activa la sintonización del dynarec ARM64 para el núcleo Cortex-A77/A55 de Kona (SD865). No implica aceleración mágica: solo ajusta flags de compilación y, potencialmente, decisiones de código condicionadas por arquitectura.

## 5. Verificación del hardware

El responsable ejecuta desde Termux:

```bash
bash scripts/device_profile_probe.sh
```

Sin root, sin instalar nada. Salida: texto plano para pegar de vuelta al agente.

## 6. Condiciones de prueba por experimento

Cada vez que se ejecute una prueba, **debe registrarse** en el informe correspondiente:

- Modelo exacto verificado con `getprop ro.product.model`.
- SoC verificado con `getprop ro.soc.model`.
- Versión de Android y nivel de API.
- RAM disponible en el momento de la prueba (`cat /proc/meminfo` justo antes).
- Estado de la batería al inicio y al fin (`termux-battery-status` si el paquete está instalado; en caso contrario, anotar manualmente).
- Temperatura inicial del dispositivo, si la herramienta seleccionada en `INSTRUMENTATION.md` lo permite.
- Aplicaciones en segundo plano cerradas antes de la prueba.
- Modo de ahorro de energía desactivado o activado, según se decida, y mantenido constante.
- Hora de inicio y fin.
- Versión exacta de Box64 (commit hash) y banderas de compilación.
- Variables de entorno `BOX64_*` aplicadas.
- Resolución y configuración gráfica del juego o carga de prueba.
- Resultados: FPS, tiempos de fotograma, duración, errores.

Si una condición no se puede medir de forma fiable, se declara como **no disponible** en lugar de inventar la cifra.

## 7. Limitaciones explícitas del entorno de ejecución previsto

1. **Sin acceso root.** No se pueden fijar frecuencias de CPU, no se puede usar `simpleperf` en modo kernel, no se pueden leer sensores térmicos protegidos. Esto se documenta y se busca alternativa viable en `INSTRUMENTATION.md`.

2. **Termux nativo es experimental para Box64** según la documentación oficial (`third_party/box64/docs/COMPILE.md` línea 255). La nota advierte explícitamente: *"Box64 in native termux is experimental and won't run linux binaries!"*. Esto obliga a evaluar la ruta **CHRoot/PRoot** en Termux como alternativa más viable. La decisión se toma en `BUILD_AND_SMOKE_TEST.md` tras probar ambas.

3. **6 GB de RAM es ajustado.** Compilar Box64 en el propio teléfono puede consumir memoria significativa. La Fase 1 debe medir el consumo de compilación antes de lanzar un `make -j$(nproc)` agresivo. Se recomienda empezar con `make -j2` o `make -j1`.

4. **Almacenamiento limitado.** El checkout de Box64 ocupa ~170 MB en este host; una compilación completa con símbolos puede superar 500 MB. La Fase 1 debe verificar el espacio antes de compilar.

5. **Estabilidad térmica.** Compilar Box64 desde el teléfono durante minutos puede inducir estrangulamiento térmico. Las sesiones de medición posteriores deben esperar a que el dispositivo recupere una temperatura base estable.
