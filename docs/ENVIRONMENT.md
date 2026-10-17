# Entorno de desarrollo y ejecución

**Documento:** `docs/ENVIRONMENT.md`
**Proyecto:** Stride Dynarec
**Fase:** 0 — Reconocimiento
**Fecha:** 2026-10-18

---

## 1. Distinción obligatoria entre dos entornos

En este proyecto conviven dos entornos distintos, y es obligatorio no mezclarlos:

| Identificador       | Descripción                                  | Hardware                                  | Rol en el proyecto                                            |
|---------------------|----------------------------------------------|-------------------------------------------|---------------------------------------------------------------|
| **E-AGENT**         | Entorno del agente (donde se ejecuta el agente) | Host Linux x86_64 virtualizado (KVM)      | Auditoría de código fuente, generación de scripts reproducibles, documentación |
| **E-DEVICE**        | Entorno del dispositivo objetivo              | Samsung Galaxy S20 FE (ARM64, Android)    | Compilación de Box64, ejecución de pruebas, medición de rendimiento |

**Regla:** Ninguna afirmación sobre el comportamiento de ejecución de Box64 es válida si no se ha medido en **E-DEVICE**. La auditoría de código y la preparación de scripts puede hacerse en **E-AGENT**.

## 2. Entorno E-AGENT (auditable por el agente directamente)

### 2.1 Sistema operativo y arquitectura

| Campo             | Valor                                                          |
|-------------------|----------------------------------------------------------------|
| Kernel            | Linux 5.10.134-013.15.kangaroo.al8.x86_64                      |
| Distribución      | Debian GNU/Linux 13 (trixie)                                   |
| Arquitectura host | `x86_64`                                                       |
| Virtualización    | KVM (hypervisor detectado en `lscpu`)                          |
| CPU               | Intel Xeon (2 núcleos, 1 hilo/núcleo)                          |
| RAM               | 4.1 GiB total, 3.6 GiB disponible                              |
| Disco             | 9.9 GiB total en `/`, 9.3 GiB libres                            |
| Swap              | 0 B                                                            |

### 2.2 Herramientas disponibles en E-AGENT

| Herramienta   | Versión                | Notas                                                  |
|---------------|------------------------|--------------------------------------------------------|
| `git`         | 2.47.3                 | OK                                                     |
| `gcc`         | 14.2.0 (Debian)        | OK                                                     |
| `g++`         | 14.2.0 (Debian)        | OK                                                     |
| `make`        | GNU make               | OK                                                     |
| `python3`     | 3.12.15                | En venv `/home/z/.venv`                                |
| `cmake`       | 4.4.4                  | Instalado vía `pip` en el venv del agente              |
| `curl`        | OK                     | OK                                                     |
| `wget`        | OK                     | OK                                                     |
| `rsync`       | OK                     | OK                                                     |
| `ar`, `ld`, `strip`, `pkg-config` | OK      | OK                                                     |

### 2.3 Herramientas NO disponibles en E-AGENT

| Herramienta                       | Estado                | Implicación                                          |
|-----------------------------------|-----------------------|------------------------------------------------------|
| `clang` / `clang++`               | NO disponible         | Box64 recomienda clang para ARM64 dynarec (en Termux nativo) |
| `ninja`                           | NO disponible         | Alternativa a `make` no disponible                   |
| `adb`                             | NO disponible         | Sin conexión al dispositivo                          |
| Termux / `pkg`                    | NO aplicable          | Solo existe en Android                               |
| Toolchain cruzado `aarch64-linux-gnu-gcc` | NO disponible | No se puede hacer compilación cruzada desde E-AGENT |
| Android NDK                       | NO disponible         | No se puede compilar para Android desde E-AGENT      |
| `qemu-user` / `qemu-aarch64`      | NO verificado         | No se puede ejecutar el binario ARM64 aquí           |

### 2.4 Implicaciones para el flujo de trabajo

El agente **no puede**:

1. Compilar Box64 para ARM64 desde E-AGENT (no hay toolchain cruzado ni NDK).
2. Ejecutar binarios ARM64 aquí (la arquitectura host es x86_64 y no hay qemu-user confirmado).
3. Conectarse al Galaxy S20 FE (no hay ADB).
4. Medir rendimiento, temperatura ni frecuencias en el dispositivo.

El agente **sí puede**:

1. Clonar Box64 y auditar su código fuente.
2. Identificar funciones, archivos y mecanismos reales en el código.
3. Generar scripts reproducibles (shell, python) que el responsable ejecutará en E-DEVICE.
4. Generar parches y proponer modificaciones en ramas `stride/*`.
5. Documentar la metodología y los criterios de aceptación.
6. Analizar los resultados que el responsable devuelva desde E-DEVICE.

## 3. Entorno E-DEVICE (previsto, pendiente de verificación)

### 3.1 Lo declarado por el responsable

| Campo                | Valor                                 |
|----------------------|---------------------------------------|
| Dispositivo          | Samsung Galaxy S20 FE                 |
| RAM                  | 6 GB                                  |
| Arquitectura         | ARM64                                 |
| Sistema operativo    | Android                               |
| Terminal previsto    | Termux                                |
| Acceso root          | No                                    |
| Compilación prevista | En el propio teléfono                 |

### 3.2 Lo que falta verificar en E-DEVICE

Toda la información de esta subsección se obtiene ejecutando los comandos del bloque de verificación en `docs/DEVICE_PROFILE.md` sección 5. Mientras no se reciban los resultados, los campos siguientes están **vacíos**.

| Campo                                | Estado        | Valor |
|--------------------------------------|---------------|-------|
| Modelo exacto                        | `[PENDIENTE]` | —     |
| SoC                                  | `[PENDIENTE]` | —     |
| GPU                                  | `[PENDIENTE]` | —     |
| Versión Android                      | `[PENDIENTE]` | —     |
| Nivel de API                         | `[PENDIENTE]` | —     |
| RAM total                            | `[PENDIENTE]` | —     |
| Almacenamiento libre                 | `[PENDIENTE]` | —     |
| Núcleos y frecuencias máximas        | `[PENDIENTE]` | —     |
| Versión de Termux                    | `[PENDIENTE]` | —     |
| `clang` disponible en Termux         | `[PENDIENTE]` | —     |
| `cmake` disponible en Termux         | `[PENDIENTE]` | —     |
| `git` disponible en Termux           | `[PENDIENTE]` | —     |
| Box64 ya instalado                   | `[PENDIENTE]` | —     |

### 3.3 Rutas de compilación previstas para Box64 en E-DEVICE

Según `third_party/box64/docs/COMPILE.md` (sección "for Termux"), existen dos rutas:

#### Ruta A — CHRoot/PRoot en Termux

```
cmake .. -D ARM64=1 -DCMAKE_C_COMPILER=gcc -DBAD_SIGNAL=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo
```

- Para dispositivos con SoC SD865, sustituir `-D ARM64=1` por `-D SD865=1`.
- Requiere un filesystem Linux ARM64 bajo CHRoot/PRoot (típicamente Ubuntu/Debian ARM64).
- **Ventaja:** puede ejecutar binarios Linux ARM64, incluido Box64 con programas de prueba x86-64.
- **Desventaja:** instalar y mantener el CHRoot consume espacio y tiempo.

#### Ruta B — Termux nativo

```
cmake .. -D TERMUX=1 -DCMAKE_C_COMPILER=clang -D CMAKE_BUILD_TYPE=RelWithDebInfo
```

- Requiere los paquetes `libandroid-sysv-semaphore` y `libandroid-spawn`.
- **Documentación oficial advierte:** *"Box64 in native termux is experimental and won't run linux binaries!"* (línea 255 de `COMPILE.md`).
- **Ventaja:** sin CHRoot, más ligero.
- **Desventaja:** no ejecuta binarios Linux ARM64, lo que limita el conjunto de pruebas.

La selección entre A y B se decide en `BUILD_AND_SMOKE_TEST.md` (Fase 1) **después** de probar ambas o, al menos, de verificar qué prerequisitos están disponibles en E-DEVICE.

### 3.4 Software base que el responsable debe instalar en Termux (lista tentativa)

```bash
# En Termux (E-DEVICE). El agente NO puede ejecutar esto.
pkg update
pkg upgrade
pkg install -y git clang cmake make pkg-config python \
               libandroid-sysv-semaphore libandroid-spawn \
               zlib
# Solo si se va a usar la Ruta A (CHRoot/PRoot):
pkg install -y proot
# Para instalar un filesystem Linux ARM64 dentro de proot:
pkg install -y proot-distro
proot-distro install ubuntu   # o debian
```

**No instalar todo de una vez sin verificar primero el espacio disponible.** El responsable debe reportar el tamaño de cada paso.

## 4. Inventario de versiones de los proyectos externos

El agente registra aquí las versiones **declaradas por la documentación oficial** de cada proyecto. Estas versiones **no se consideran verificadas** hasta que el responsable las confirme en E-DEVICE ejecutando los comandos correspondientes.

| Proyecto  | URL de versión                                  | Cómo verificar versión            | Estado        |
|-----------|-------------------------------------------------|-----------------------------------|---------------|
| Box64     | https://github.com/ptitSeb/box64/commits/main   | `box64 --version`                 | `[PENDIENTE]` |
| Wine      | https://gitlab.winehq.org/wine/wine/-/tags      | `wine --version`                  | `[PENDIENTE]` |
| DXVK      | https://github.com/doitsujin/dxvk/releases      | `dxvk --version` (no siempre)     | `[PENDIENTE]` |
| FEX-Emu   | https://github.com/FEX-Emu/FEX/releases         | `FEXLoader --version`             | `[PENDIENTE]` |

## 5. Registro del commit de Box64 fijado en este proyecto

| Campo            | Valor                                                          |
|------------------|----------------------------------------------------------------|
| URL de origen    | https://github.com/ptitSeb/box64.git                           |
| Rama             | `main`                                                         |
| Commit           | `27860e6aee72dd33c2588d081652d6e9becc1089`                     |
| Asunto           | `[RV64_DYNAREC] Fix VCVTPD2PS result clearing (#4572)`         |
| Autor            | Zhijin Zeng <zhijin.zeng@spacemit.com>                         |
| Fecha            | 2026-10-17 13:24:09 +0800                                      |
| Verificado en    | `third_party/box64/.git/HEAD`                                  |

Comando para reproducir:

```bash
cd third_party/box64
git rev-parse HEAD           # debe imprimir 27860e6aee72dd33c2588d081652d6e9becc1089
git log -1 --format='%H %ai %an %s'
```

## 6. Cómo se conservan los registros de cada experimento

Cada experimento se documenta en `reports/` siguiendo esta plantilla mínima:

```markdown
# Experimento <ID> — <nombre>

- **Fecha:** <ISO 8601 UTC>
- **Dispositivo:** <modelo exacto verificado>
- **SoC:** <verificado>
- **Android:** <versión> / API <nivel>
- **Box64:** commit <hash>, build <flags>
- **Variables BOX64_*:** <lista>
- **Carga:** <descripción>
- **Duración:** <minutos>
- **Repeticiones:** <n>

## Resultados
| Repetición | Métrica A | Métrica B | … |
|------------|-----------|-----------|---|
| 1          | …         | …         | … |
| 2          | …         | …         | … |
| 3          | …         | …         | … |

## Estadísticas
- Media, desviación típica, min, max.

## Limitaciones
- <lo que no se pudo medir y por qué>

## Reproducibilidad
- <comandos exactos>

## Conclusión
- <lo que el resultado justifica o descarta>
```

Los experimentos negativos (sin mejora) también se documentan y conservan. Un experimento fallido produce conocimiento útil.

## 7. Pendiente de Fase 0 que requiere el responsable

Para cerrar la Fase 0, el responsable debe devolver al agente:

1. La salida completa del bloque de verificación de `docs/DEVICE_PROFILE.md` sección 5.
2. La salida de `df -h $HOME` y `df -h /data` para confirmar espacio disponible.
3. La salida de `pkg list-installed` (o equivalente) para conocer qué paquetes Termux ya están instalados.
4. Una indicación explícita de si tiene acceso root o no (lo declarado es "no", pero conviene confirmarlo).
5. Una indicación sobre si prefiere la Ruta A (CHRoot/PRoot) o la Ruta B (Termux nativo) como primera opción a probar, o si desea que el agente decida en función de los datos anteriores.

El agente no pedirá al responsable que elija entre alternativas técnicas que puede evaluar él mismo. En este caso, la elección entre A y B depende de información que solo el responsable puede obtener en el dispositivo, por lo que es legítimo pedir su intervención.
