# Verificación de la versión 0.5

El proyecto se comprueba con Godot 4.7.2 real. Python coordina la importación, ejecuta las escenas de pruebas y rechaza errores del motor. Las pruebas no reemplazan el guardado personal.

| Comando | Cobertura |
|---|---|
| `tools/check.ps1` | Navegación, controles, guardado y cuatro niveles |
| `-Expansion` | Seis perfiles, compras de maestros, streaming, entregas y música |
| `-Remaster` | IA, menús, migración de guardados y música |
| `-Fixes` | Escudos, quiz y consumo de recompensas |
| `-Mejoras` | Animación, enemigos, carriles, encuentros y Prefecto |
| `-Incentives` | Monedero, tienda, retratos, maestros, reliquias, récords, logros y galería |
| `-Music` | Catorce loops, entrada real al maestro, mezcla, silencio y persistencia |
| `-Combat` | Cuatro estudiantes contra ambos jefes |
| `-Routes` / `-Matrix` | Recorridos completos y matriz larga de plataformas y enemigos |

La auditoría de música comprueba duración entre 60 y 90 segundos, muestras sin saturación, niveles RMS, continuidad del loop y arreglos diferentes. Los límites de efectos y la prioridad del daño se prueban dentro del motor.

`tools/build_windows.py` usa las plantillas estándar de Godot, exporta un ejecutable con recursos embebidos y verifica menú, personajes, cuatro niveles, tienda, galería, récords, pausa y graduación. El ZIP y el ejecutable quedan en `build/`, fuera del seguimiento de Git.

La diversión, la mezcla en equipos distintos y el uso con un mando físico requieren evaluación jugando. Las pruebas automáticas verifican los comportamientos indicados, no esas apreciaciones.

## Última validación del proyecto limpio

Comprobado el 23 de octubre de 2026, después de retirar las versiones antiguas y regenerar la caché:

| Suite | Resultado |
|---|---|
| Integración | 58 / 58 |
| Expansión | 51 / 51 |
| Remaster | 24 / 24 |
| Correcciones | 37 / 37 |
| Mejoras | 111 / 111 |
| Incentivos | 116 / 116 |
| Música | 43 / 43 |
| Combates contra jefes | 8 / 8 |
| Arranques del ejecutable exportado | 11 / 11 |

En total: **440 comprobaciones de sistemas**, **8 combates** y **11 arranques exportados**, sin fallos ni errores del motor. La auditoría conserva 38 WAV usados por el juego y valida las catorce pistas musicales actuales. Los informes detallados se regeneran con los comandos anteriores; Git conserva este resumen y las métricas del compositor.
