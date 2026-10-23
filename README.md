# TECNO AVENTURA III: LA MISIÓN DEL TÍTULO

Versión **0.4.1 — Pulso del campus**, construida sobre el proyecto existente de Godot 4 y GDScript. Mantiene cuatro niveles, los cuatro estudiantes, Aztli, los objetivos académicos, los coleccionables, el guardado, los dos jefes y la graduación.

## Jugar

Abre **JUGAR.cmd** o **build/Windows/TECNO_AVENTURA_III_0.4.1.exe**. Para compartir, extrae **build/TECNO_AVENTURA_III-Windows.zip**. El ejecutable incluye sus recursos y no necesita Godot, Python, Internet ni instalación. Para desarrollo, importa project.godot en Godot 4 y pulsa F5.

Las versiones anteriores del ejecutable se conservan. El lanzador prioriza la 0.4.1. Antes de esta actualización se respaldó el proyecto completo en **backups/tecno-aventura-0.3-before-remaster.zip**.

> **Nota:** las correcciones de revisión descritas abajo están en el código fuente, pero **todavía no en el ejecutable**. El .exe y el ZIP de build/ siguen siendo los de la 0.4.1 publicada; hay que volver a exportar para incluirlas.

## 0.5 en desarrollo (rama mejoras-0.5)

Se trabaja por etapas en la rama `mejoras-0.5`; `main` conserva la 0.4.1 publicada.

**Etapa 1 — Animaciones e interfaz**

- **Movimiento:** squash & stretch (anticipación agachada al despegar, estiramiento en el aire y aplastamiento al aterrizar, proporcional a la caída) e inclinación según velocidad y aceleración. Las piernas ahora tienen rodilla y el ciclo de carrera avanza con la distancia recorrida, así los pies no patinan. Hay polvo al frenar o deslizarse.
- **Hit-stop visual:** al conectar un golpe, la pose se congela unos 70 ms, el objetivo destella, aparece una chispa y la cámara da un pequeño golpe. No escala el tiempo del motor ni pausa temporizadores, así que los combates contra jefes duran lo mismo.
- **Solo visual:** todos los efectos los dibuja student_art.gd a partir de datos de pose de player.gd (`pose_scale`, `pose_tilt`, `run_phase`, `hitstop`). El cuerpo, la cápsula de colisión, la hitbox y el nodo visual no se escalan ni rotan. El salto no se retrasa: la anticipación es puramente gráfica.
- **Interfaz:** un Theme de Godot compartido (scripts/ui_theme.gd) con paleta única y botones con estados normal, hover, presionado, foco y deshabilitado. Los botones crecen levemente al pasar el ratón y se hunden al pulsar. Hay transición de entrada en cada pantalla, Segoe UI seminegrita, contorno y sombra en el texto, y sombras en los paneles.
- **HUD con iconos vectoriales** (scripts/hud_icon.gd): corazones llenos/vacíos, vidas, créditos, USB, título, reloj de entrega y potenciadores activos (pluma, beca, café).
- **Pruebas:** tests/mejoras_suite.gd (`.\tools\check.ps1 -Mejoras`). tests/pose_sheet.tscn genera docs/poses-05.png con las poses; necesita ventana, no headless.

## Correcciones de revisión (posteriores a la 0.4.1)

Corrigen errores sin cambiar el balance ni la arquitectura. Respaldo previo: **backups/tecno-aventura-0.4.1-before-fixes.zip**; el estado publicado también está en git con la etiqueta **v0.4.1**.

- **Escudo del jefe:** cada golpe de mochila registra como máximo un impacto por objetivo (player.gd guarda los objetivos alcanzados y los reinicia al empezar otro ataque). Antes, el escudo mostraba «ESCUDO» y su sonido en cada frame del golpe, unas 12 veces. Además, ese aviso espera 0.4 s antes de repetirse. El daño a enemigos y jefes no cambia: un enemigo aturdido sigue pudiendo recibir el golpe cuando termina su aturdimiento, como antes.
- **Quiz de la biblioteca:** las tres respuestas tienen el mismo estilo (antes la correcta aparecía resaltada), su orden se mezcla en cada intento y la respuesta se comprueba por valor, no por posición.
- **Letrero de combate:** en los niveles 3 y 4 se calcula a partir de la entrada de la arena (`arena_gate_x` / `arena_sign_x` en level_data.gd). Ya no está fijo en x=5130, al inicio del nivel.
- **Habilidad de Diego:** si la beca ya está activa, Q no gasta la recarga y muestra «Ya tienes escudo».
- **Escudo por partida:** la beca ya no se guarda en progress.json ni pasa de un estudiante a otro. Cada nivel empieza con el estado inicial del estudiante (solo Diego con escudo), y elegir otro estudiante también la reinicia. Las partidas antiguas que la tenían guardada la ignoran al cargar. Consecuencia: la beca obtenida a mitad de nivel (quiz o recompensa) no se conserva al salir y pulsar Continuar.
- **Recompensas únicas:** corazones, café y becas tienen ID determinista por nivel, tramo y posición (`ex_<nivel>_<tramo>_heart_650`, `1_heart_x3200`…). Una vez recogidos no reaparecen al alejarte y volver, ni al guardar y continuar. Se registran con el checkpoint del nivel, igual que los enemigos derrotados, así que reiniciar el nivel desde cero los restaura y el balance de cada intento no cambia.
- **Limpieza:** se simplificó la condición redundante de faros en level_extension.gd y expansion_data.gd (`part == 0`).
- **Pruebas:** nueva suite tests/fixes_suite.gd con 37 comprobaciones, `.\tools\check.ps1 -Fixes`. Se ajustó la prueba de habilidades de Diego para gastar primero su escudo inicial.

## Cambios de la 0.4.1

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
| Diego | Cuatro corazones y beca inicial | Activa un escudo, recarga de 14 s (no se gasta si ya tienes escudo) |
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
- Control de versiones: git, rama main, con la etiqueta v0.4.1 para el estado publicado. build/, backups/, .godot/ y \_\_pycache\_\_/ quedan fuera del repositorio.

Comprobaciones en PowerShell:

    .\tools\check.ps1
    .\tools\check.ps1 -Expansion
    .\tools\check.ps1 -Remaster
    .\tools\check.ps1 -Routes
    .\tools\check.ps1 -Matrix
    .\tools\check.ps1 -Combat
    .\tools\check.ps1 -Fixes
    .\tools\check.ps1 -Mejoras

El verificador utiliza Python 3 y Godot real. Puedes indicar otra ruta de Godot con -Godot. Las pruebas utilizan guardados aislados y no reemplazan la partida personal. Los generadores anteriores se conservaron como herramientas históricas; ejecuta compose_electro_score.py para la banda sonora actual.

Se incluyen las licencias de Godot y componentes. No se distribuyen fuentes de Windows, logotipos oficiales del TecNM ni recursos de Super Mario. Aztli y el campus son interpretaciones originales de la temática del Tecnológico de Tláhuac III.
