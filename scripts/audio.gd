extends Node

var music: AudioStreamPlayer
var sfx: AudioStreamPlayer


func _ready() -> void:
	music = $Music
	sfx = $SFX
	if DisplayServer.get_name() == "headless":
		return
	music.stream = load("res://assets/audio/sky_garden.wav")
	music.volume_db = -18.0
	music.finished.connect(music.play)
	apply_settings()


func apply_settings() -> void:
	if Profile.data.settings.music:
		if not music.playing:
			music.play()
	else:
		music.stop()


func play_cue(cue: String = "tap") -> void:
	if DisplayServer.get_name() == "headless" or not Profile.data.settings.sfx:
		return
	sfx.stream = load("res://assets/audio/%s.wav" % cue)
	sfx.volume_db = -12.0
	sfx.play()


func shutdown() -> void:
	music.stop()
	sfx.stop()
	music.stream = null
	sfx.stream = null
