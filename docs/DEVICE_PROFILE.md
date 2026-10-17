# Perfil del dispositivo objetivo

**Documento:** `docs/DEVICE_PROFILE.md`
**Proyecto:** Stride Dynarec
**Fase:** 0 — Reconocimiento
**Fecha:** 2026-10-18

---

## 1. Advertencia de verificación

> **El agente NO tiene acceso físico al dispositivo objetivo.**
> La información de este documento se divide en dos categorías claramente separadas:
>
> - **Datos declarados por el responsable:** marcados como `[DECLARADO]`.
> - **Datos verificados en el dispositivo:** marcados como `[VERIFICADO]`. Hasta que el responsable no ejecute los comandos de la sección 5 y devuelva los resultados, esta categoría estará vacía o incompleta.
> - **Datos inferidos de fuentes públicas:** marcados como `[REFERENCIA]` con la URL de origen.
>
> **No se asume nada a partir del nombre comercial del teléfono.** El Galaxy S20 FE se comercializó en al menos dos variantes principales con SoC distinto. Esto afecta directamente a las opciones de compilación de Box64.

## 2. Datos declarados por el responsable

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

## 5. Comandos reproducibles para verificar el hardware

El responsable debe ejecutar este bloque **desde Termux en el propio teléfono** y copiar/pegar el texto resultante de vuelta al agente. No requiere root. No instala nada.

```bash
# ============================================================
# Stride Dynarec — Verificación de perfil de dispositivo
# Ejecutar desde Termux. Sin root. Sin instalar nada.
# ============================================================
echo "===== STRIDE_DYNAREC_DEVICE_PROFILE ====="
echo "[fecha]           $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[host]            $(hostname 2>/dev/null || echo n/a)"
echo ""

echo "----- 1. Modelo exacto y variante -----"
echo "ro.product.model          = $(getprop ro.product.model)"
echo "ro.product.name           = $(getprop ro.product.name)"
echo "ro.product.device         = $(getprop ro.product.device)"
echo "ro.product.brand          = $(getprop ro.product.brand)"
echo "ro.boot.hwc_model         = $(getprop ro.boot.hwc_model)"
echo "ro.boot.hwc_platform      = $(getprop ro.boot.hwc_platform)"
echo "ro.hardware               = $(getprop ro.hardware)"
echo ""

echo "----- 2. SoC -----"
echo "ro.soc.manufacturer       = $(getprop ro.soc.manufacturer)"
echo "ro.soc.model              = $(getprop ro.soc.model)"
echo "ro.board.platform         = $(getprop ro.board.platform)"
echo ""

echo "----- 3. Android -----"
echo "ro.build.version.release  = $(getprop ro.build.version.release)"
echo "ro.build.version.sdk      = $(getprop ro.build.version.sdk)"
echo "ro.build.id               = $(getprop ro.build.id)"
echo "ro.product.cpu.abilist    = $(getprop ro.product.cpu.abilist)"
echo ""

echo "----- 4. Memoria -----"
head -3 /proc/meminfo
echo ""

echo "----- 5. Almacenamiento -----"
df -h "$HOME" 2>/dev/null
df -h /data 2>/dev/null
echo ""

echo "----- 6. CPU (núcleos y frecuencias máximas) -----"
echo "nproc                    = $(nproc)"
for c in /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_max_freq; do
  [ -r "$c" ] && echo "$c = $(cat $c)  (= $(($(cat $c))/1000)) MHz)"
done 2>/dev/null
echo ""

echo "----- 7. GPU / GLES (parcial, sin root) -----"
dumpsys SurfaceFlinger 2>/dev/null | grep -E "GLES|GL_VERSION|GL_RENDERER" | head -5
echo ""

echo "----- 8. Termux -----"
echo "TERMUX_VERSION            = ${TERMUX_VERSION:-n/a}"
echo "PREFIX                    = ${PREFIX:-n/a}"
command -v termux-info >/dev/null 2>&1 && termux-info | head -20 || echo "(termux-info no disponible)"
echo ""

echo "----- 9. Toolchain disponible en Termux -----"
for t in clang clang++ gcc g++ make cmake git curl wget pkg-config; do
  if command -v "$t" >/dev/null 2>&1; then
    printf "  %-12s OK   %s\n" "$t" "$(command -v $t)"
  else
    printf "  %-12s NO\n" "$t"
  fi
done
echo ""

echo "----- 10. Versiones de cadenas de herramientas -----"
clang --version 2>/dev/null | head -1
gcc --version 2>/dev/null | head -1
cmake --version 2>/dev/null | head -1
git --version 2>/dev/null
echo ""

echo "----- 11. Box64 ya instalado (si existe) -----"
command -v box64 >/dev/null 2>&1 && box64 --version 2>&1 | head -5 || echo "(box64 no en PATH)"
echo ""

echo "===== END ====="
```

## 6. Condiciones de prueba que deben registrarse en cada experimento

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
