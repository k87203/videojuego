extends Node
## Source-only moving/rendered probe. Main owns screenshot timing and clean shutdown.
var app
var samples: Array[Dictionary] = []
var report_written := false
func _ready() -> void:
	Progress.session_only = true
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	Input.action_press("right")
	Input.action_press("run")

func _process(delta: float) -> void:
	if app.frame > 30 and app.frame < 720:
		samples.append({"dt": delta * 1000, "process": Performance.get_monitor(Performance.TIME_PROCESS) * 1000, "physics": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, "calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)})
	# Write after Main has computed its frame statistics. Logging to redirected
	# output during the sample perturbs the result on Windows/mapped drives.
	if app.frame >= 721 and not report_written:
		report_written = true
		var file := FileAccess.open("res://docs/render-profile.json", FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(samples))
