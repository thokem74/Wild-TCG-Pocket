extends Node

const CUES: Array[String] = [
	"tap",
	"reveal",
	"attack",
	"windup",
	"flame",
	"tide",
	"gale",
	"knockout",
	"attach",
	"heal",
	"boost",
	"draw",
	"deploy",
	"retreat",
	"turn",
	"victory",
	"defeat",
	"draw_result"
]
var streams: Dictionary = {}
var music: AudioStreamPlayer
var battle_music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var voice_index: int = 0
var battle_context: bool = false
var fade: Tween


func _ready() -> void:
	music = $Music
	battle_music = $BattleMusic
	for child: Node in $Voices.get_children():
		voices.append(child)
	for cue: String in CUES:
		streams[cue] = load("res://assets/audio/%s.wav" % cue)
	music.stream = load("res://assets/audio/sky_garden.wav")
	battle_music.stream = load("res://assets/audio/battle.wav")
	music.finished.connect(music.play)
	battle_music.finished.connect(battle_music.play)
	apply_settings()


func set_battle_context(enabled: bool) -> void:
	if battle_context == enabled:
		return
	battle_context = enabled
	apply_settings()


func apply_settings() -> void:
	if fade != null:
		fade.kill()
	if DisplayServer.get_name() == "headless" or not Profile.data.settings.music:
		music.stop()
		battle_music.stop()
	else:
		fade = create_tween().set_parallel(true)
		for player: AudioStreamPlayer in [music, battle_music]:
			var active: bool = (player == battle_music) == battle_context
			if active and not player.playing:
				player.volume_db = -60.0
				player.play()
			fade.tween_property(player, "volume_db", -18.0 if active else -60.0, 0.45)
			if not active:
				fade.tween_callback(player.stop).set_delay(0.45)
	if not Profile.data.settings.sfx:
		for voice: AudioStreamPlayer in voices:
			voice.stop()


func play_cue(cue: String = "tap") -> void:
	if DisplayServer.get_name() == "headless" or not Profile.data.settings.sfx:
		return
	if not streams.has(cue):
		return
	var voice: AudioStreamPlayer = voices[voice_index]
	voice_index = (voice_index + 1) % voices.size()
	voice.stream = streams[cue]
	voice.volume_db = -12.0
	voice.play()


func shutdown() -> void:
	if fade != null:
		fade.kill()
	music.stop()
	battle_music.stop()
	music.stream = null
	battle_music.stream = null
	for voice: AudioStreamPlayer in voices:
		voice.stop()
		voice.stream = null
	streams.clear()
