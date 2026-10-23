extends Node
## Original generated PCM music and effects. Replace WAV files without changing gameplay.
var music: AudioStreamPlayer
var current_track := ""
var voices: Array[AudioStreamPlayer] = []
var cache: Dictionary = {}
var shutting_down := false
var music_players: Array[AudioStreamPlayer] = []
var fade: Tween
const PREWARM := ["jump", "attack", "hit", "hurt", "coin", "power", "victory", "alert", "windup", "enemy_attack", "checkpoint", "ui_hover", "land", "step", "slide", "shield", "door", "eagle", "ability_alex", "ability_valeria", "ability_diego", "ability_sofia", "crumble", "trial", "urgent_chase", "epic_boss", "epic_final"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Music", "Effects"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	for i in 2:
		var music_player := AudioStreamPlayer.new()
		music_player.bus = "Music"
		add_child(music_player)
		music_players.append(music_player)
	music = music_players[0]
	for i in 12:
		var voice := AudioStreamPlayer.new()
		voice.bus = "Effects"
		add_child(voice)
		voices.append(voice)
	apply_volume()
	# Prepare action sounds before gameplay; first-use disk reads must not stall a fight.
	for sound_name in PREWARM: cache_resource(sound_name)

func cache_resource(sound_name: String) -> void:
	if cache.has(sound_name): return
	var path := "res://assets/audio/" + sound_name + ".wav"
	if ResourceLoader.exists(path): cache[sound_name] = load(path)

func warm_level(id: int) -> void:
	cache_resource("campus_%d" % id)
	cache_resource("campus_%d_intense" % id)

func apply_volume() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(Progress.music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Effects"), linear_to_db(maxf(Progress.effects_volume, 0.0001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), Progress.music_volume <= 0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Effects"), Progress.effects_volume <= 0)

func track(track_name: String, aligned: bool = false, fade_seconds: float = 0.65) -> void:
	if shutting_down: return
	if current_track == track_name:
		return
	cache_resource(track_name)
	if not cache.has(track_name): return
	var previous_tempo: float = MusicManager.bpm(current_track)
	current_track = track_name
	var stream = cache[track_name]
	if stream is AudioStreamWAV:
		# Imported WAVs may use QOA/ADPCM. Compressed bytes are not PCM frames.
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	if is_instance_valid(fade): fade.kill()
	var previous := music
	var play_from := fmod(previous.get_playback_position(), maxf(0.1, stream.get_length())) if aligned else 0.0
	if not aligned and previous.playing:
		var phase := fposmod(previous.get_playback_position() * previous_tempo / 60.0, 1.0)
		play_from = phase * 60.0 / MusicManager.bpm(track_name)
	music = music_players[1] if music == music_players[0] else music_players[0]
	music.stop()
	music.stream = stream
	music.volume_linear = 0
	music.play(play_from)
	fade = create_tween().set_parallel(true)
	# Equal-power fades avoid the deep volume dip caused by interpolating decibels.
	fade.tween_property(music, "volume_linear", db_to_linear(-8.0), fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade.tween_property(previous, "volume_linear", 0.0, fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade.chain().tween_callback(func():
		previous.stop()
		previous.stream = null)

func shutdown() -> void:
	shutting_down = true
	if is_instance_valid(fade): fade.kill()
	for music_player in music_players:
		music_player.stop()
		music_player.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null
	cache.clear()

func sfx(effect: String, pitch: float = 1.0) -> void:
	if shutting_down: return
	var path := "res://assets/audio/" + effect + ".wav"
	if not cache.has(effect):
		if not ResourceLoader.exists(path):
			return
		cache[effect] = load(path)
	for voice in voices:
		if not voice.playing:
			voice.stream = cache[effect]
			voice.pitch_scale = pitch
			voice.volume_db = -13 if effect in ["step", "land"] else -7
			voice.play()
			return
