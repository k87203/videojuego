# Verificación — versión 0.4.1 «Pulso del campus»

Entorno: Godot 4.7.2 stable en Windows, Compatibility / OpenGL 3.3, AMD Radeon Vega 6. La actualización se realizó sobre el proyecto existente. La referencia local solo se leyó; el análisis está en REFERENCIA_Y_DISENO_04.md.

## Comprobaciones del motor

| Grupo | Resultado | Registros |
|---|---|---|
| Compatibilidad y campaña | 58 aprobadas, cero fallos | test-results.txt, integration.log |
| Personajes, entregas, audio y persistencia | 42 aprobadas, cero fallos | expansion-results.txt, expansion.log |
| Menú, IA nueva y migración | 24 aprobadas, cero fallos | remaster-results.txt, remaster.log |

**124 comprobaciones aprobadas.** La importación compila los scripts y el verificador revisa 63 referencias explícitas y 45 archivos WAV de 16 bits. Los tests utilizan un perfil aislado y guardados desechables; no reemplazan la partida personal.

Las comprobaciones nuevas ejercitan movimiento mediante la física real: persecución acelerada, aviso antes de la carga, interrupción mediante un golpe, velocidad de la embestida, esquiva con recarga, disparos dirigidos, pérdida y recuperación de visión, protección de bordes al patrullar y retroceder, salto de un obstáculo bajo, reacción musical a un encuentro y migración efectiva de una escena guardada de la 0.3.

## Cuatro rutas y duración

La geometría se redujo de 225 600 a 96 000 píxeles por nivel. Los cuatro niveles conservan sus introducciones y objetivos; cada distrito utiliza cuatro encuentros combinados en lugar de diez repeticiones. Permanecen las tres entregas y las tres introducciones/checkpoints originales; hay 18 faros adicionales por nivel.

Las rutas emplean entradas de carrera, salto, ataque e interacción con física a 60 Hz. No teletransportan durante los recorridos completos. **Utilizan invulnerabilidad para aislar la geometría.** Los niveles 1 y 2 llegan a la salida; 3 y 4 llegan a sus arenas. El combate se prueba aparte.

La ejecución final de las rutas midió:

| Nivel | Estudiante | Tiempo de ruta | Entregas | Vidas perdidas |
|---|---|---:|---:|---:|
| 1 | Alex | 257.6 s / 4:18 | 3 | 0 |
| 2 | Valeria | 229.6 s / 3:50 | 3 | 0 |
| 3 | Diego | 278.8 s / 4:39 | 3 | 0 |
| 4 | Sofía | 246.0 s / 4:06 | 3 | 0 |

route-results.txt y routes.log contienen la ejecución más reciente y sus tiempos exactos. El objetivo de diseño es 4–5 minutos para un jugador promedio. La carrera continua del bot, sobre todo con Valeria, puede ser más corta; explorar, combatir y repetir desafíos modifica esos tiempos. **No se ha medido todavía una duración humana promedio.**

Se aprobaron además **32 recorridos cortos**: cuatro estudiantes × cuatro niveles × dos ventanas de 4 800 píxeles, una de plataformas móviles y otra de derrumbes avanzados/combinaciones. Parten de posiciones controladas y habilitan la pluma. No equivalen a 16 campañas completas. Registros: route-matrix-results.txt, routes-*-*.log.

## Ocho combates con salud normal

Los bots usan movimiento, salto y ataque desde la entrada de la arena. No se altera la salud o los temporizadores del jefe ni se llama directamente a su función de daño. Diego utiliza sus cuatro corazones y protección inicial normal.

| Estudiante | BUG 404 | Corazones finales | Doctor, fases 1–3 | Corazones finales |
|---|---:|---:|---:|---:|
| Alex | 9.0 s | 1 | 12.0 s | 2 |
| Valeria | 8.9 s | 1 | 12.0 s | 2 |
| Diego | 9.1 s | 3 | 12.0 s | 4 |
| Sofía | 8.8 s | 1 | 12.0 s | 2 |

**Ocho victorias, cero vidas perdidas.** Registros: combat-results.txt y combat.log. La prueba utiliza conocimiento de posiciones y estados para decidir; estos tiempos no representan la habilidad de un jugador promedio. La integración comprueba también los escudos, los objetivos, las tres fases y la graduación.

## Audio y presentación

Se recompusieron trece temas de 148–180 BPM, con 64 compases y ocho frases. Utilizan bajo Reese, subgrave, supersaws, arpegios, batería, fills, sidechain y secciones de construcción/drop/bajada. Se renovaron once efectos existentes y se añadieron tres. Total disponible: 21 temas y 24 efectos.

La síntesis usa fuentes propias de 32 kHz / 16 bits; Godot realiza la importación comprimida. music-analysis.json contiene duración, tempo, pico y RMS de los recursos recompuestos. Los nuevos temas presentan picos de 0.94 y RMS cercano a 0.22–0.24 en las pistas principales; el balance subjetivo aún requiere escucha de usuarios. No se copiaron grabaciones, melodías ni recursos comerciales.

MusicManager recibe eventos de ataques, daño, salto aéreo, encuentros, persecuciones, entregas y jefes. Las versiones de exploración/intensidad comparten tempo y posición de reproducción. Las transiciones duran 0.7 s con potencia constante y alineación de fase del pulso; no se retarda la entrada del jugador. Los bucles respetan la duración completa de los WAV comprimidos. Audio de acción y arreglos del nivel se preparan antes de necesitarlos para evitar lecturas de primer uso durante un ataque.

El menú utiliza una ilustración vectorial nueva, tipografía de mayor peso, fondo dinámico oscuro, partículas limitadas, halos, parallax, estudiante y Aztli animados, pulsos musicales y botones con foco, transiciones y sonido. Se verificó el ajuste de texto y se mantiene la navegación existente.

## Rendimiento observado

Capturas de desarrollo revisadas:

| Escena | Muestra | Media | P99 |
|---|---:|---:|---:|
| Menú nuevo | 150 frames | 60.1 FPS | 16.67 ms |
| Zona de acción, nivel 1 | 150 frames | 60.3 FPS | 16.67 ms |
| Plataformas, nivel 3 | 150 frames | 60.0 FPS | 16.67 ms |
| Persecución en movimiento, carga de tramos y enemigos | 690 frames | 60.0 FPS | 16.67 ms |

Archivos: menu-04.png, accion-04.png, plataformas-04.png, streaming-04.png y sus registros *-render.log. El probe móvil recorre aproximadamente 4 300 píxeles; activa persecución, enemigos y reconstrucción de tramos. La captura utiliza invulnerabilidad para mantener el ensayo de rendimiento separado del combate.

Se detectó que escribir mensajes del propio diagnóstico durante la muestra, mediante salida redirigida a la unidad del proyecto, producía pausas de más de 100 ms. La medición final elimina esas escrituras hasta después de calcular FPS. El informe de tiempos de proceso se escribe después de la muestra en render-profile.json. La construcción de un tramo tardó aproximadamente 0.7–1.4 ms en el diagnóstico independiente.

Las muestras no garantizan 60 FPS durante toda la campaña ni en otro hardware. Se mantienen como máximo seis tramos próximos; se desactiva trabajo lejano, se conservan IDs persistentes y se reutilizan estilos y audio. Los registros exportado-04-*-render.log documentan aparte las capturas del ejecutable final.

## Windows y preservación

La versión actual se exporta como **build/Windows/TECNO_AVENTURA_III_0.4.1.exe**; JUGAR.cmd la prioriza. Se mantienen los ejecutables anteriores. La distribución compartible es build/TECNO_AVENTURA_III-Windows.zip.

El constructor utiliza la plantilla oficial de Godot 4.7.2 x86_64, incorpora sus recursos y aplica icono y versión. Prueba siete arranques desde otra carpeta, sin editor ni --path: menú, selección, cuatro niveles con personajes distintos y graduación. Verifica CRC del ZIP y SHA256 del ejecutable. windows-build.json y build/Windows/SHA256.txt identifican la compilación exacta. Se incluyen las licencias del motor.

Respaldo previo a esta actualización: **backups/tecno-aventura-0.3-before-remaster.zip**. Se conservaron las cuatro escenas de nivel, la escena principal, los perfiles, objetivos, logros y las herramientas anteriores. El guardado mantiene formato 1 y reconoce también los checkpoints de la 0.4 inicial. Migra checkpoints largos al distrito equivalente. También migra los identificadores de recompensas y enemigos por distrito, elimina duplicados al condensar tramos y registra course_revision=4 para no repetir la conversión. Estas condiciones se probaron con una escena real y un archivo desechable, incluido un segundo guardado/carga. Los recursos musicales reemplazados siguen disponibles en ese respaldo y en los generadores anteriores.

Se revisaron capturas renderizadas del ejecutable exportado del menú y los cuatro niveles: medias de 59.8–60.2 FPS en 150 frames, P99 de 16.67–18.06 ms. El menú renovado se conserva en exportado-04-menu.png. Los tamaños y la huella exacta del paquete final se consultan en windows-build.json.

## Evaluación pendiente

- Partida humana completa para valorar diversión, variedad, dificultad y duración promedio de 4–5 minutos.
- Escucha y ajuste de mezcla en altavoces y auriculares; el diseño electrónico está implementado, pero su valoración es subjetiva.
- Pulido artístico adicional de animaciones dentro del juego; el arte sigue siendo vectorial y procedural original.
- Prueba prolongada en otras computadoras, mando físico y ZIP en otra PC Windows.

Estas evaluaciones pendientes no se marcan como terminadas.
