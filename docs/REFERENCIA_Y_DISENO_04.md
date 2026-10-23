# Análisis y decisiones de la versión 0.4

## Proyecto actual antes de los cambios

La versión 0.3 ya tenía cuatro niveles, personajes, físicas estables, objetivos, guardado y jefes. Sus niveles alcanzaban 225 600 píxeles: cada distrito repetía diez tramos y dos se dedicaban a recuperación. La expansión daba lugar a recorridos automáticos de 8–10 minutos, con poca diferenciación dentro de cada distrito.

La persecución ordinaria era de 112–145 px/s frente a 330–400 px/s de carrera del estudiante; solo los cazadores alcanzaban 290. Los relojes disparaban sin un aviso propio visible. Las variantes compartían buena parte del movimiento y el golpe ocurría únicamente al pulsar, aunque la animación continuara.

El audio de exploración iba de 116 a 132 BPM con timbres de pluck/campana y bajo ligero. El menú empleaba tarjetas redondeadas, fondos claros y el mismo rig pequeño del juego ampliado.

## Referencia local consultada

Ruta: Y:\rivera\proyecto_escuela_juego-main. Se leyeron teacher.gd, chalk.gd, dropper.gd, eraser.gd, player.gd y las secciones de dirección de persecución y pulso de level.gd.

La referencia no es uniformemente más rápida: su profesor patrulla a 32 px/s y el personaje usa una escala gráfica distinta. Su eficacia proviene de los avisos antes del lanzamiento, las fases de recuperación, las amenazas con trayectorias legibles y la organización de los eventos durante la persecución. Comparar velocidades absolutas entre escalas no sería útil para equilibrar Tecno Aventura.

## Aplicación original

- Se mantuvo y extendió la máquina de estados existente. Las tareas saltan, los virus cargan y esquivan con recarga, los robots anuncian su embestida y los relojes fijan una puntería con anticipación limitada. No se utilizó el profesor, la tiza, el borrador gigante ni la secuencia de persecución de la referencia.
- Los avisos duran 0.30–0.50 segundos según enemigo. Las cargas tienen duración limitada y recuperación; acertar un golpe puede interrumpirlas. El enemigo comprueba visión, suelo y espacio de salto.
- Se redujeron los distritos de diez a cuatro encuentros y se mezclaron mecánicas entre tramos: las rutas altas desembocan en puentes/talleres; los finales varían entre plataformas móviles, derrumbes y obstáculos mixtos. Las tres entregas y los objetivos originales se preservan.
- El audio se recompuso con melodías y síntesis propias: 64 compases, ocho frases, bajos Reese y subgrave, supersaws, arpegios, batería, fills y envolvente de sidechain. La energía de la electrónica rápida es una orientación general; no se transcribieron canciones comerciales.
- El menú nuevo utiliza geometría e ilustración propias. Reutiliza únicamente la paleta y la identidad de los personajes de Tecno Aventura, manteniendo intactos sus flujos de selección y guardado.

No se escribió ni modificó ningún archivo del proyecto de referencia. No se copiaron sus recursos, código, mapas, personajes ni secuencias. La actualización del proyecto actual tiene respaldo en backups/tecno-aventura-0.3-before-remaster.zip.
