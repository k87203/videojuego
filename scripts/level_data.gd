extends RefCounted
## Hand-authored paths. Coordinates are feet positions; platforms use top-left.
const TITLES := ["Bienvenido al TEC", "Caos en los Salones", "Invasión Informática", "La Titulación Final"]
const SUBTITLES := ["JARDINES · ENTRADA PRINCIPAL", "BIBLIOTECA · AULAS", "LABORATORIOS · TALLERES", "AUDITORIO · RECTORÍA"]
const BRIEFINGS := ["Doctor Reprobación robó nuestros créditos. ¡Recuperemos el futuro! Muévete con A / D y salta con Espacio.", "Recupera tu credencial en la biblioteca. Las plataformas se mueven: observa antes de saltar.", "Enciende el interruptor del laboratorio y encuentra a BUG 404. Las trampas eléctricas se apagan por momentos.", "Ya casi estás. Recupera el último fragmento y derrota al Doctor. ¡Te ayudaré a romper su escudo!"]

static func layout(level: int) -> Dictionary:
	var d := {
		"ground": [[0, 1050], [1220, 1320], [2700, 1300], [4180, 2420]],
		"platforms": [[480, 505, 180], [760, 415, 160], [1420, 505, 160], [1660, 410, 180], [1870, 315, 180], [2220, 475, 160], [2850, 500, 180], [3150, 415, 160], [3410, 330, 170], [3700, 490, 170], [4280, 510, 170], [4510, 410, 180], [4760, 315, 180], [5100, 500, 180]],
		"moving": [], "hazards": [[2340, 70], [3790, 90]],
		"enemies": [["task", 830, 610], ["task", 1780, 610], ["task", 3030, 610], ["task", 3500, 610], ["task", 4580, 610], ["task", 5250, 610]],
		"usb": [[1950, 274], [4830, 273]], "checkpoints": [1370, 2880, 4950],
		"coffee": [650, 3300], "shield": [2450], "hearts": [3200, 4900], "exit": 6360
	}
	if level == 2:
		d.ground = [[0, 990], [1230, 1280], [2780, 1210], [4250, 2350]]
		d.platforms.append([4030, 660, 180])
		d.moving = [[1000, 530, 150, 120, 0, 3.5], [2530, 500, 160, 130, -70, 4], [3990, 510, 160, 160, 0, 3.5]]
		d.enemies = [["task", 770, 610], ["clock", 1750, 370], ["robot", 2240, 610], ["task", 3350, 610], ["clock", 3860, 400], ["robot", 4670, 610], ["clock", 5400, 420]]
		d.hazards = [[3450, 90], [5180, 80]]
	if level == 3:
		d.ground = [[0, 1070], [1270, 1190], [2740, 1250], [4220, 2380]]
		d.moving = [[1090, 520, 160, 75, -70, 3.8], [2480, 510, 170, 160, 0, 3.6], [4010, 515, 150, 110, 0, 3.4]]
		d.enemies = [["virus", 780, 610], ["robot", 1600, 610], ["virus", 2270, 610], ["clock", 3190, 350], ["robot", 3450, 610], ["virus", 4440, 610], ["robot", 4900, 610]]
		d.hazards = [[1810, 100], [3000, 110], [3650, 100], [4710, 110]]
	if level == 4:
		d.ground = [[0, 950], [1210, 1290], [2800, 1180], [4250, 2350]]
		d.platforms.append([2530, 660, 220])
		d.moving = [[960, 515, 140, 160, -40, 3.2], [2520, 510, 150, 160, -75, 3.5], [4000, 510, 150, 150, -50, 3.0]]
		d.enemies = [["robot", 720, 610], ["clock", 1660, 370], ["task", 1900, 610], ["virus", 2300, 610], ["robot", 3170, 610], ["clock", 3660, 370], ["virus", 4410, 610], ["task", 4720, 610]]
		d.hazards = [[2130, 100], [3330, 95], [4610, 110]]
	# Keep all original coordinates and pickup ordering. New districts are streamed afterwards.
	d["length"] = preload("res://scripts/expansion_data.gd").LENGTH
	d["arena_x"] = d.length - 1000
	d["exit"] = d.length - 240
	return d
