# TECNO AVENTURA III: LA MISIÓN DEL TÍTULO

Versión **0.4.1 — Pulso del campus**, construida sobre el proyecto existente de Godot 4 y GDScript. Mantiene cuatro niveles, los cuatro estudiantes, Aztli, los objetivos académicos, los coleccionables, el guardado, los dos jefes y la graduación.

## Jugar

Abre **JUGAR.cmd** o **build/Windows/TECNO_AVENTURA_III_0.4.1.exe**. Para compartir, extrae **build/TECNO_AVENTURA_III-Windows.zip**. El ejecutable incluye sus recursos y no necesita Godot, Python, Internet ni instalación. Para desarrollo, importa project.godot en Godot 4 y pulsa F5.

Las versiones anteriores del ejecutable se conservan. El lanzador prioriza la 0.4.1. Antes de esta actualización se respaldó el proyecto completo en **backups/tecno-aventura-0.3-before-remaster.zip**.

## Cambios actuales

- **Menú nuevo:** estética nocturna y neón, tipografía de mayor peso, ilustración vectorial original de estudiante y águila, iluminación, partículas limitadas, parallax de ratón, pulsos sincronizados con la música, entrada escalonada y botones con respuesta visual/sonora y foco de teclado.
- **Electrónica original:** trece arreglos recompuestos, de 148 a 180 BPM, con subgraves, bajo Reese, sintetizadores supersaw, arpegios, percusión, transiciones de construcción/drop/bajada y sidechain. Cada tema tiene 64 compases y ocho frases. Se renovaron once efectos y se agregaron windup, enemy_attack y ui_hover. Total de recursos: 21 temas y 24 efectos.
- **MusicManager reactivo:** un solo encuentro puede intensificar la música; salto aéreo, ataques, daño, persecuciones, contrarrelojes y fases de jefe alimentan su estado. Las versiones calmada/intensa mantienen posición musical. Las transiciones de 0.7 s conservan potencia y alinean la fase del pulso entre tempos; las acciones del jugador no se retrasan para ajustarse a la música.
- **Cuatro niveles más concentrados:** se pasó de 225 600 a 96 000 píxeles por nivel. Cada distrito combina cuatro encuentros en lugar de diez tramos repetidos. Se alternan rutas altas, combate, puentes, plataformas móviles, derrumbes, electricidad y velocidad. Los descansos se redujeron a cuatro aperturas estratégicas. Hay 18 faros adicionales por nivel, además de los tres de cada introducción.
- **IA diferenciada:** patrullas más rápidas, detección a 520 píxeles con línea de visión, aceleración, avisos antes de atacar, recuperación posterior y tres grados de dificultad. Las tareas saltan; los virus se lanzan y los de mayor nivel esquivan ataques tempranos; los robots cargan; los relojes anticipan ligeramente el movimiento y disparan. Los enemigos verifican bordes, aterrizaje y espacio superior antes de saltar obstáculos.
- **Control y respuesta:** mayor aceleración, frenado y control aéreo, ataque cada 0.34 s y contacto activo durante su animación. Se añadieron ondas de impacto a golpes y recompensas, iluminación suave al pulso y retroalimentación musical inmediata.

## Referencia y autoría

Se revisaron teacher.gd, chalk.gd, dropper.gd, player.gd y la dirección de persecución de level.gd en el proyecto local indicado por el usuario. El análisis está en **docs/REFERENCIA_Y_DISENO_04.md**. Se tomó como orientación la claridad de los avisos, el contraste entre espera/ataque y la densidad de acción. No se copiaron archivos, personajes, mapas, código, secuencias ni recursos de ese proyecto. No se emplean melodías ni audio de Geometry Dash.

## Estudiantes y controles

| Estudiante | Ventaja | Q / C / LB |
|---|---|---|
| Alex | Equilibrado | Impulso rápido, recarga de 4 s |
| Valeria | Más velocidad, doble salto desde el comienzo | Salto aéreo; también funciona el segundo Espacio |
| Diego | Cuatro corazones y beca inicial | Activa un escudo, recarga de 14 s |
| Sofía | Mayor salto y detección de escondites | Radar durante 5 s, recarga de 8 s |

| Acción | Teclado | Mando |
|---|---|---|
| Mover | A/D o flechas | Stick/cruceta |
| Saltar | Espacio/W/↑ | A |
| Correr | Shift | RB |
| Deslizar/agacharse | S/↓ | B |
| Golpe de mochila | J/X | X |
| Habilidad | Q/C | LB |
| Interactuar | E/Enter | Y |
| Pausa | Esc | Start |

Mantén salto para alcanzar mayor altura. La pluma desbloquea el doble salto para los demás estudiantes. Puedes pisar enemigos, atacar durante su aviso o aprovechar su recuperación. Los robots necesitan dos golpes; un golpe acertado interrumpe su carga.

## Campaña y objetivos

1. **Bienvenido al TEC:** entrada, jardines, pluma, secretos, primer documento y circuitos de plataformas.
2. **Caos en los Salones:** credencial, biblioteca, pregunta académica opcional, plataformas móviles y enfrentamientos.
3. **Invasión Informática:** interruptor de la compuerta, descargas, virus, talleres y BUG 404.
4. **La Titulación Final:** desafíos combinados, documento final y Doctor Reprobación en tres fases.

Completa las tres entregas de cada nivel: cruza el arco en 22 segundos. Si se acaba el tiempo, reapareces en el faro sin perder una vida. Recoge el fragmento y usa la salida con E. Aztli sigue dando consejos, señalando secretos y abriendo oportunidades de ataque a los jefes cada diez segundos.

Se mantienen dos USB por nivel y la mención honorífica al reunir las ocho. Cada 100 créditos concede una vida extra; el café aumenta velocidad durante 12 segundos. Los checkpoints recuperan salud. Las calificaciones dependen de secretos y daño.

## Duración, guardado y compatibilidad

El objetivo de diseño actual es **4–5 minutos por nivel para un jugador promedio**. Las rutas automáticas a carrera continua midieron 4:18, 3:50, 4:39 y 4:06, sin exploración completa y con combate de jefe separado. Es una medición de referencia; la duración humana promedio aún requiere pruebas con jugadores.

El guardado mantiene el formato versión 1 en user://progress.json. Conserva personaje, puntuación, habilidades, documentos, USB, niveles, volúmenes, sellos y checkpoints. Los faros de los recorridos largos de la 0.3 se migran al distrito correspondiente de los nuevos; los checkpoints anteriores a la expansión no cambian. Continuar restaura un faro, no la posición exacta entre faros. Nueva partida pide confirmación antes de reemplazar progreso.

## Comprobaciones y estado

Consulta **docs/VERIFICACION.md**: importación real, pruebas de compatibilidad y sistemas, rutas, matriz de plataformas, IA, combates, mediciones gráficas y exportación Windows. El menú, audio, IA y recorridos descritos están implementados.

Pendiente de evaluación humana: diversión, variedad, duración promedio, dificultad con controles normales y mezcla en auriculares/altavoces. El arte es vectorial y procedural original; el pulido artístico de animaciones de juego puede continuar. Las muestras locales no garantizan el mismo rendimiento en otra computadora. Falta comprobar un mando físico y el ZIP en otra PC.

## Desarrollo

- scripts/main.gd: navegación, selección, HUD, resultados y graduación.
- scripts/menu_screen.gd y menu_showcase.gd: presentación nueva, separada de los flujos existentes.
- scripts/player.gd, student_art.gd y characters.gd: controles, perfiles y animaciones.
- scripts/enemy.gd y boss.gd: enemigos y jefes.
- scripts/level_data.gd: introducciones existentes.
- scripts/expansion_data.gd y level_extension.gd: distritos compactos y carga de hasta seis tramos.
- scripts/progress.gd: guardado compatible.
- scripts/music_manager.gd y sound.gd: eventos, reloj musical y mezcla.
- tools/compose_electro_score.py: compositor original reproducible con Python, NumPy y SciPy.
- tools/build_windows.py: plantilla oficial 4.7.2, icono, siete arranques de prueba, ZIP y SHA256.

Comprobaciones en PowerShell:

    .\tools\check.ps1
    .\tools\check.ps1 -Expansion
    .\tools\check.ps1 -Remaster
    .\tools\check.ps1 -Routes
    .\tools\check.ps1 -Matrix
    .\tools\check.ps1 -Combat

El verificador utiliza Python 3 y Godot real. Puedes indicar otra ruta de Godot con -Godot. Las pruebas utilizan guardados aislados y no reemplazan la partida personal. Los generadores anteriores se conservaron como herramientas históricas; ejecuta compose_electro_score.py para la banda sonora actual.

Se incluyen las licencias de Godot y componentes. No se distribuyen fuentes de Windows, logotipos oficiales del TecNM ni recursos de Super Mario. Aztli y el campus son interpretaciones originales de la temática del Tecnológico de Tláhuac III.
