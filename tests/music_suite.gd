extends Node
var app
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)

func ticks(count: int = 3) -> void:
	for i in count: await get_tree().physics_frame
	await get_tree().process_frame

func reset_effects() -> void:
	for voice in Sound.voices:
		voice.stop()
		voice.stream = null
	Sound.last_effect.clear()

func _ready() -> void:
	Progress.session_only = true
	Progress.reset_data()
	Progress.audio_muted = false
	Progress.music_volume = 0.45
	Progress.effects_volume = 0.8
	Sound.apply_volume()
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await ticks()
	for base in MusicManager.TEMPOS:
		var names: Array = [base]
		if str(base).begins_with("campus_"): names.append(str(base) + "_intense")
		for name in names:
			Sound.cache_resource(name)
			var stream: AudioStream = Sound.cache[name]
			check(stream.get_length() >= 59.99 and stream.get_length() <= 90, "%s has a full 60–90 second arrangement" % name)
		if names.size() == 2:
			check(absf(Sound.cache[names[0]].get_length() - Sound.cache[names[1]].get_length()) < 0.001, "Calm and intense arrangements remain synchronized")
	app.start_level(1)
	await ticks()
	app.world.set_process(false)
	app.world.extension.set_process(false)
	MusicManager.enter_level(1)
	check(Sound.current_track == "campus_1", "Each level chooses its own exploration theme")
	var stream = Sound.music.stream
	check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and absf(float(stream.loop_end) / stream.mix_rate - stream.get_length()) < 0.01, "WAV playback loops over the full imported arrangement")
	MusicManager.context(0, false, 1, false)
	check(Sound.current_track == "epic_boss", "A boss has its own music with priority over exploration")
	MusicManager.context(0, false, 0, false)
	check(Sound.current_track == "epic_boss" and MusicManager.hold > 7, "Eight-second hold prevents rapid musical switching")
	check(MusicManager.bpm("campus_1") >= 160 and MusicManager.bpm("campus_3") >= 170, "Exploration uses fast arcade tempos")
	app.start_level(4)
	await ticks()
	app.world.extension.set_process(false)
	app.world.player.invulnerable = 999
	app.world.player.position = app.world.boss.home + Vector2(-300, 0)
	await ticks(3)
	check(app.world.boss.active and Sound.current_track == "teacher_suspense", "Reaching the teacher boss starts suspense music through the real arena trigger")
	MusicManager.context(0, false, 3, false)
	check(Sound.current_track == "epic_final", "The teacher's final phase raises the suspense arrangement")
	app.world.set_process(false)
	app.pause_game()
	await ticks()
	var sliders: Array[HSlider] = []
	var mute: Button
	for child in app.ui.get_children():
		if child is HSlider: sliders.append(child)
		if child.has_meta("audio_mute"): mute = child
	check(sliders.size() == 2 and is_instance_valid(mute), "Pause exposes both volume sliders and a mute button directly")
	sliders[0].value = 32
	sliders[1].value = 57
	check(is_equal_approx(Progress.music_volume, 0.32) and is_equal_approx(Progress.effects_volume, 0.57), "Pause volume controls update music and effects independently")
	var music_bus := AudioServer.get_bus_index("Music")
	var effects_bus := AudioServer.get_bus_index("Effects")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music_bus)), 0.32), "Volume changes reach the audio mixer")
	mute.pressed.emit()
	check(Progress.audio_muted and AudioServer.is_bus_mute(music_bus) and AudioServer.is_bus_mute(effects_bus), "Mute silences music and effects together")
	check(not Sound.sfx("coin"), "Muted effects do not occupy voices")
	mute.pressed.emit()
	check(not Progress.audio_muted and is_equal_approx(Progress.music_volume, 0.32) and not AudioServer.is_bus_mute(effects_bus), "Unmute restores the chosen levels")
	var held: float = MusicManager.hold
	await ticks(30)
	check(get_tree().paused and is_equal_approx(MusicManager.hold, held), "Pause freezes music policy while keeping its controls responsive")
	app.resume_game()
	reset_effects()
	check(Sound.voices.size() == 6, "Effects have exactly six reusable voices")
	check(Sound.sfx("coin") and not Sound.sfx("coin"), "Repeated coins are limited by a per-effect cooldown")
	Sound.last_effect["coin"] = -100
	check(Sound.sfx("coin"), "Two coin sounds can overlap within the group cap")
	Sound.last_effect["coin"] = -100
	check(not Sound.sfx("coin"), "A third simultaneous copy of one effect is rejected")
	reset_effects()
	check(Sound.sfx("step") and Sound.sfx("jump") and not Sound.sfx("slide"), "Movement sounds respect their shared overlap limit")
	reset_effects()
	for effect in ["step", "jump", "attack", "coin", "alert", "windup"]: Sound.sfx(effect)
	var busy := Sound.voices.filter(func(v): return v.playing).size()
	check(busy == 6, "A mixed burst fills the six-voice pool")
	check(Sound.sfx("hurt"), "Damage feedback can replace a lower-priority sound when the pool is full")
	check(Sound.voices.filter(func(v): return v.playing).size() <= 6, "Priority replacement never exceeds the total voice limit")
	check(not Sound.voices.any(func(v): return v.playing and v.get_meta("effect", "") == "step"), "The quiet footstep yields to the damage cue")
	check(not Sound.sfx("missing_effect"), "An unknown sound is skipped without an engine error")
	await persistence()
	print("MUSIC RESULT: %d checks, %d failures" % [checks, failures])
	app.queue_free()
	Sound.shutdown()
	await ticks()
	await get_tree().create_timer(0.2).timeout
	OS.delay_msec(250)
	get_tree().quit(1 if failures else 0)

func persistence() -> void:
	var original_path: String = Progress.save_path
	Progress.save_path = "user://music-controls-test-only.json"
	Progress.session_only = false
	Progress.audio_muted = true
	Progress.save_game()
	Progress.audio_muted = false
	Progress.music_volume = 0.9
	Progress.effects_volume = 0.9
	Progress.load_game()
	check(Progress.audio_muted and is_equal_approx(Progress.music_volume, 0.32) and is_equal_approx(Progress.effects_volume, 0.57), "Mute and both volume levels survive a real save reload")
	DirAccess.remove_absolute(Progress.save_path)
	Progress.save_path = original_path
	Progress.session_only = true
