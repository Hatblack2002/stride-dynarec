<p align="center">
  <img src="docs/img/stride_dynarec_logo.jpg" alt="Stride Dynarec" width="320">
</p>

# Stride Dynarec

Investigación y optimización de la traducción dinámica x86-64 → ARM64 para juegos de PC en Android (Snapdragon).

- **Estado:** Fase 0 — Reconocimiento
- **Repo:** https://github.com/Hatblack2002/stride-dynarec
- **Base:** Box64 @ `27860e6aee72dd33c2588d081652d6e9becc1089` (main)
- **Dispositivo:** Samsung Galaxy S20 FE (variante por verificar)

## Misión

Identificar y reducir costes innecesarios en la traducción dinámica x86-64 → ARM64. No es un emulador nuevo: audita y optimiza Box64.

```
inspeccionar → medir → formular hipótesis → proponer → implementar → validar → documentar
```

## Estructura

```
stride-dynarec/
├── README.md
├── .gitignore
├── docs/
│   ├── img/stride_dynarec_logo.jpg
│   ├── DEVICE_PROFILE.md
│   ├── ENVIRONMENT.md
│   ├── BASELINE_PLAN.md
│   ├── BUILD_AND_SMOKE_TEST.md       (Fase 1)
│   ├── INSTRUMENTATION.md            (Fase 3)
│   └── OPTIMIZATION_PROPOSAL_001.md  (Fase 4)
├── reports/
│   ├── BASELINE_REPORT.md            (Fase 2)
│   ├── OPTIMIZATION_REPORT_001.md    (Fase 5)
│   └── GAME_VALIDATION_001.md        (Fase 6)
├── patches/
├── scripts/
│   ├── bootstrap_box64.sh
│   └── device_profile_probe.sh
└── third_party/                      (no versionado, ver .gitignore)
    └── box64/                        (clonado por bootstrap_box64.sh)
```

## Reproducir el entorno

```bash
git clone https://github.com/Hatblack2002/stride-dynarec.git
cd stride-dynarec
bash scripts/bootstrap_box64.sh        # clona Box64 en el commit fijado
bash scripts/device_profile_probe.sh   # en Termux, en el dispositivo
```

## Base de referencia

| Campo | Valor |
|---|---|
| Proyecto | Box64 |
| URL | https://github.com/ptitSeb/box64 |
| Commit | `27860e6aee72dd33c2588d081652d6e9becc1089` |
| Fecha | 2026-10-17 |
| Licencia | MIT |

## Proyectos de referencia (sin modificación en Fase 0)

| Proyecto | URL | Rol |
|---|---|---|
| Box64 | https://github.com/ptitSeb/box64 | Traducción x86-64 → ARM64 (base) |
| FEX-Emu | https://github.com/FEX-Emu/FEX | Alternativa de traducción de CPU |
| Wine | https://gitlab.winehq.org/wine/wine | API de Windows |
| DXVK | https://github.com/doitsujin/dxvk | D3D → Vulkan |

## Reglas

- No inventar resultados, archivos, funciones ni comandos.
- No declarar compilado lo no compilado, ni probado lo no probado.
- No mezclar variables en una comparación sin documentar.
- No tocar barreras de memoria ni comprobaciones de seguridad sin análisis riguroso.
- Respetar licencias upstream y conservar copyright.
- Toda modificación se documenta y se asocia a un commit independiente.

## Estado actual

Completado (Fase 0 parcial):
- Auditoría real del dynarec ARM64 de Box64 (`src/dynarec/arm64/`, `dynarec_native.c:FillBlock64`, `dynablock.c:DBGetBlock`, `dynarec.c:EmuRun`).
- Verificación de `BOX64_DYNACACHE` y variables asociadas en `docs/USAGE.md`.
- Verificación de rutas de compilación Termux (CHRoot/PRoot vs nativo).
- Documentos iniciales: `DEVICE_PROFILE.md`, `ENVIRONMENT.md`, `BASELINE_PLAN.md`.

Pendiente:
- Salida de `device_profile_probe.sh` ejecutado en el dispositivo.
- `BUILD_AND_SMOKE_TEST.md` (Fase 1).

## Licencia

El contenido propio de Stride Dynarec se publica bajo MIT. El clon de Box64 en `third_party/` mantiene su licencia MIT original.
