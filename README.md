# TECNO AVENTURA III: La misión del título

Juego de plataformas 2D hecho con **Godot 4 y GDScript**. Versión actual: **0.5**.

Recorre cuatro niveles del campus, completa las entregas y recupera los fragmentos del título. Incluye enemigos con ataques anunciados, encuentros de aula y laboratorio, persecuciones del Prefecto y dos jefes.

## Jugar

1. Instala Godot **4.7.2**, la versión con la que se ha verificado el proyecto.
2. Importa `project.godot` y pulsa **F5**. No necesitas Python ni conexión a Internet para jugar.
3. En Windows también puedes abrir **JUGAR.cmd**. Encuentra Godot mediante la variable `GODOT`, el `PATH` o el nombre oficial del ejecutable en Descargas. Si Godot no está disponible y ya hay una exportación actual en `build/Windows/`, abre esa exportación.

La partida se guarda en `user://progress.json`, fuera de esta carpeta. Las pruebas usan guardados aislados.

## Controles

| Acción | Teclado | Mando |
|---|---|---|
| Mover | A/D o flechas | Stick / cruceta |
| Saltar | Espacio / W / ↑ | A |
| Correr | Shift | RB |
| Agacharse / deslizar | S / ↓ | B |
| Atacar | J / X | X |
| Habilidad | Q / C | LB |
| Interactuar | E / Enter | Y |
| Pausa | Esc | Start |

## Contenido

- **Cuatro estudiantes iniciales:** Alex, Valeria, Diego y Sofía, con habilidades diferentes.
- **Dos maestros comprables:** Maestra Luz y Profe Nico; 120 monedas cada uno. Sus habilidades usan valores ya establecidos.
- **Tienda ilustrada:** sudaderas, gorra, bufanda y una compra única de un corazón extra. En las arenas de jefe se conserva el límite de salud original.
- **Monedero persistente:** las compras y los atuendos se conservan al empezar otra aventura. Los IDs de recompensas evitan volver a cobrar monedas y puntos del mismo origen.
- **Doce reliquias ocultas:** tres por nivel. La galería muestra las ilustraciones con un candado hasta desbloquear su vista completa. Se mantienen las ocho USB.
- **Récords y siete logros:** mejor calificación y tiempo por nivel, guardados entre partidas.
- **Música original:** electrónica arcade de 160–180 BPM en juego, con suspenso exclusivo para el Doctor Reprobación. Loops de 64–76 segundos, volumen y silencio en pausa, y un máximo de seis efectos simultáneos.
- **Escenario despejado:** los avisos largos de la parte inferior están desactivados.

## Estructura

| Carpeta | Contenido |
|---|---|
| `scenes/` | Menú y cuatro niveles |
| `scripts/` | Lógica, personajes, interfaz y dibujo vectorial |
| `assets/` | Arte y audio usados por el juego |
| `tests/` | Pruebas de sistemas, combates y recorridos |
| `tools/` | Verificación, capturas, exportación y compositor actual |
| `docs/` | Verificación y métricas de audio actuales |
| `licenses/` | Avisos de licencia del motor Godot |

## Comprobaciones

Necesitas Python 3.12 o posterior y Godot. En PowerShell:

```powershell
.\tools\check.ps1
.\tools\check.ps1 -Expansion
.\tools\check.ps1 -Remaster
.\tools\check.ps1 -Fixes
.\tools\check.ps1 -Mejoras
.\tools\check.ps1 -Incentives
.\tools\check.ps1 -Music
.\tools\check.ps1 -Combat
```

Puedes indicar `-Godot "ruta/al/ejecutable"`. En otros sistemas: `python tools/check.py --godot /ruta/a/godot`, con las opciones `--music`, `--incentives`, `--expansion`, `--combat`, etc. `-Routes` y `-Matrix` ejecutan los recorridos largos.

Consulta [docs/VERIFICACION.md](docs/VERIFICACION.md). Los informes y las capturas generados se excluyen de Git.

## Exportar para Windows

Instala las plantillas oficiales de exportación de la misma versión desde el editor de Godot. Después:

```powershell
python tools/build_windows.py
```

El script exporta la versión actual, comprueba once pantallas y genera:

- `build/Windows/TECNO_AVENTURA_III.exe`
- `build/TECNO_AVENTURA_III-Windows.zip`

La exportación incluye los recursos y puede jugarse sin Godot ni Python. `build/` está excluido de Git; para distribuir el ZIP usa **GitHub Releases**.

## Regenerar música

Los WAV incluidos ya permiten jugar. Solo para volver a sintetizarlos:

```powershell
python -m pip install -r tools/requirements.txt
python tools/compose_arcade_score.py
```

El compositor genera notas, percusión y melodías originales, sin grabaciones ni canciones de entrada. Las métricas están en [docs/campus-loops-analysis.json](docs/campus-loops-analysis.json).

## Subir a GitHub

Sube el proyecto con Git o GitHub Desktop para respetar `.gitignore`. Incluye los archivos `.gd`, `.uid`, `.tscn`, `.svg`, `.wav`, sus configuraciones `.import` y los archivos raíz. No incluyas `.godot/`, `build/`, respaldos ni partidas personales. Godot reconstruye su caché al importar.

El repositorio conserva su historial local. Los ejecutables anteriores, la música sin uso, los compositores sustituidos y las capturas históricas se retiraron del árbol de trabajo.

## Créditos

Arte vectorial, ilustraciones del campus y música sintetizada originales del proyecto. Aztli y el campus son interpretaciones propias de la temática escolar; no se distribuyen logotipos oficiales ni canciones comerciales. Los avisos de Godot y sus componentes están en [licenses/](licenses/).
