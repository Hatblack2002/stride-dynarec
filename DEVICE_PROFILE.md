# Perfil del dispositivo

Fuente de verdad del hardware y del pin. Cerrado el 2026-10-18 por el director técnico.

## Hardware

| Componente | Valor |
|---|---|
| Dispositivo | Samsung Galaxy S20 FE 5G |
| SoC | Snapdragon 865 (kona, SM8250) |
| CPU | 4×Cortex-A55 + 3×Cortex-A77 + 1×Cortex-A77 prime |
| GPU | Adreno 650 |
| RAM | 6 GB nominales, ~5.76 GiB usables |
| SO | Android 13 (SDK 33) |
| Entorno | Termux (sin PC) |
| Root | No requerido para B0 |

## Pin principal

| Campo | Valor |
|---|---|
| Backend | Box64 |
| Tag | `v0.4.4` |
| Hash | `2f130fab1d6e1a4ee8a71dc60cfdfcc839ad192a` |
| Fecha | 2026-08-02 |
| Resolución | `git rev-parse v0.4.4` en tiempo de bootstrap |

## Pin secundario (referencia, no base)

| Campo | Valor |
|---|---|
| Commit | `27860e6aee72dd33c2588d081652d6e9becc1089` |
| Uso | Comparaciones futuras. No se usa como línea base. |

## Justificación del pin principal

- `v0.4.4` es el tag publicado más reciente en el momento del cierre de la especificación.
- El commit `27860e6` (main del día) es un parche RISC-V; no toca la ruta ARM64.
- Una línea base debe ser un punto fijo, no un snapshot de main.

## Capas fuera de alcance en B0

- Wine (LGPL) — compatibilidad Windows.
- DXVK + Vulkan + Turnip — capa gráfica.

Ambas se integran en fases posteriores, con su propia instrumentación.

## CoreMark

Prueba sintética de funcionamiento. Verifica que Box64 ejecuta correctamente un binario x86-64 estático. No es prueba de compatibilidad con juegos ni de rendimiento gráfico ni de puntuación oficial CoreMark.

- Binario: `benchmarks/coremark_x86_64` (estático, x86-64, ITERATIONS=2000)
- Binario breve: `benchmarks/coremark_x86_64_brief` (ITERATIONS=10, fuera de B0)
- Construcción: workflow `.github/workflows/build-coremark-x86_64.yml`
- Sin argumentos de ejecución.

## Limitaciones explícitas

1. Sin root → no se fijan frecuencias de CPU, no se usa `simpleperf` en modo kernel, no se leen sensores térmicos protegidos.
2. Termux nativo es experimental para Box64 según `docs/COMPILE.md` del upstream. B0 compila con `-DARM64=1 -DBAD_SIGNAL=ON` y `gcc` (Ruta A del `docs/COMPILE.md`).
3. 6 GB de RAM es ajustado. `h1_executor.sh` usa `make -j2`.
4. Caché: aislada por experimento. Nunca `~/.cache/box64`.
