extends RefCounted
## Character data shared by gameplay, portraits and save migration.
const IDS := ["alex", "valeria", "diego", "sofia"]
const SPECS := {
	"alex": {"name": "Alex", "role": "EQUILIBRADO", "description": "Control preciso e impulso rápido para cruzar peligros.", "skill": "Impulso", "cooldown": 4.0, "walk": 265.0, "run": 360.0, "jump": 590.0, "health": 3, "primary": "23b6b1", "dark": "179796", "accent": "ffd47c", "bag": "d77b3f", "hair": "222c42", "skin": "efb58e"},
	"valeria": {"name": "Valeria", "role": "VELOCIDAD", "description": "Más velocidad y doble salto disponible desde el inicio.", "skill": "Salto aéreo", "cooldown": 5.0, "walk": 300.0, "run": 400.0, "jump": 590.0, "health": 3, "primary": "ef788d", "dark": "ba4e70", "accent": "9af5e3", "bag": "6b7eb1", "hair": "593c3c", "skin": "dba37e"},
	"diego": {"name": "Diego", "role": "RESISTENCIA", "description": "Cuatro corazones y un escudo que puedes volver a activar.", "skill": "Escudo", "cooldown": 14.0, "walk": 245.0, "run": 330.0, "jump": 590.0, "health": 4, "primary": "e6ac4f", "dark": "ba8037", "accent": "8cddff", "bag": "4e86a2", "hair": "654332", "skin": "bb825f"},
	"sofia": {"name": "Sofía", "role": "EXPLORACIÓN", "description": "Salta con agilidad y localiza escondites con su radar.", "skill": "Radar", "cooldown": 8.0, "walk": 280.0, "run": 370.0, "jump": 615.0, "health": 3, "primary": "a58adc", "dark": "795da9", "accent": "9ef2bd", "bag": "4d9c8d", "hair": "303b56", "skin": "e8ad8c"}
}

static func spec(id: String) -> Dictionary:
	return SPECS.get(id, SPECS.alex)
