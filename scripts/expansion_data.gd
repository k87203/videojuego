extends RefCounted
## Authored sequence of 18 districts per level; the original 6,600-pixel route is retained.
const START := 6600
const CHUNK := 1200
const CHUNKS_PER_DISTRICT := 4
const DISTRICT := CHUNK * CHUNKS_PER_DISTRICT
const COUNT := 18
const LENGTH := START + DISTRICT * COUNT + 3000
const NAMES := [
	["Sendero del ahuehuete", "Patio de las ciencias", "Puente del canal", "Corredor de tutorías", "Azotea fotovoltaica", "Huerto del campus", "Zona deportiva", "Pasarela del humedal", "Plaza de las becas", "Ruta del servicio social", "Jardín botánico", "Arcada de ingenierías", "Biblioteca al aire libre", "Terraza del águila", "Pabellón de proyectos", "Reto de créditos", "Bosque de Aztli", "Explanada del título"],
	["Ala de humanidades", "Archivo de mapas", "Galería de lectura", "Entrega a contrarreloj", "Escalera de enciclopedias", "Taller de escritura", "Pasillo de exámenes", "Puente de las aulas", "Sala de consulta", "Préstamo urgente", "Hemeroteca", "Laberinto de apuntes", "Pabellón de idiomas", "Mezanine de las ciencias", "Club de robótica", "Última entrega", "Jardín de estudio", "Consejo académico"],
	["Red de fibra óptica", "Taller de prototipos", "Pasarela del servidor", "Respaldo de emergencia", "Generadores del campus", "Centro de monitoreo", "Alerta del cortafuegos", "Túnel de mantenimiento", "Banco de pruebas", "Ventana de actualización", "Núcleo eléctrico", "Fábrica de drones", "Red de investigación", "Cámaras de enfriamiento", "Puente de circuitos", "Recuperación del sistema", "Sala de control", "Umbral de BUG 404"],
	["Archivo de servicios", "Patio de las generaciones", "Puente administrativo", "Turno de titulación", "Bóveda de documentos", "Galería de egresados", "Inspección sorpresa", "Corredor de proyectos", "Terraza del auditorio", "Entrega de expedientes", "Sala de dictámenes", "Pasarela del jurado", "Museo de ingeniería", "Escalera de honores", "Pabellón del futuro", "Firma de último minuto", "Jardín de graduación", "Antesala del Doctor"]
]
const RECIPES := ["terraces", "library", "moving", "sprint", "collapse", "garden", "pursuit", "bridges", "workshop", "sprint", "electric", "pursuit", "library", "collapse", "moving", "sprint", "garden", "mixed"]

static func district_at(x: float) -> int:
	return clampi(int(floor((x - START) / DISTRICT)), 0, COUNT - 1)

static func title(level: int, index: int) -> String:
	return NAMES[level - 1][clampi(index, 0, COUNT - 1)]

static func checkpoint_x(index: int) -> float:
	return START + index * CHUNK + 140.0

static func migrate_checkpoint(x: float, layout_version: int) -> float:
	if layout_version >= 4 or x < START: return x
	# Preserve district progress when migrating the long 0.3 courses.
	if x >= 224000: return LENGTH - 1380.0
	var old_index := clampi(int((x - START - 140) / CHUNK), 0, 179)
	var district := old_index / 10
	var part := mini(3, int((old_index % 10) * 0.4))
	return checkpoint_x(district * CHUNKS_PER_DISTRICT + part - part % 4)

static func migrate_id(uid: String) -> String:
	if not uid.begins_with("ex_"): return uid
	var parts := uid.split("_")
	if parts.size() < 5 or not parts[2].is_valid_int(): return uid
	var old_index := int(parts[2])
	if old_index < 0 or old_index >= 180: return uid
	parts[2] = str((old_index / 10) * CHUNKS_PER_DISTRICT + mini(3, int((old_index % 10) * 0.4)))
	return "_".join(parts)

static func valid_checkpoint(x: float) -> bool:
	if is_equal_approx(x, LENGTH - 1380.0): return true
	var index := roundi((x - START - 140) / CHUNK)
	return index >= 0 and index < COUNT * CHUNKS_PER_DISTRICT and index % CHUNKS_PER_DISTRICT == 0 and absf(x - checkpoint_x(index)) < 0.1
