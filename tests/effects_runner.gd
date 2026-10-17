extends Node

var ui: Control
var baseline: Dictionary
var failures: int = 0
var checks: int = 0
var canvas: SubViewport
var suffix: String = ""


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func reset(actor: int = 0) -> void:
	ui.show_screen("Home")
	ui.rules.state = baseline.duplicate(true)
	ui.rules.state.turn = actor
	Profile.data.battle = ui.rules.state.duplicate(true)
	ui.show_screen("Battle")
	ui.get_node("AITimer").stop()


func finish() -> void:
	if ui.get_node("BattleEffects").busy:
		await ui.get_node("BattleEffects").finished
	ui.get_node("AITimer").stop()


func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://builds/previews")
	canvas.get_texture().get_image().save_png(
		"res://builds/previews/effects-%s%s.png" % [name, suffix]
	)


func _ready() -> void:
	await get_tree().process_frame
	Profile.data = Profile.fresh_data()
	canvas = SubViewport.new()
	canvas.size = Vector2i(720, 1280)
	if OS.get_cmdline_user_args().has("--tall"):
		canvas.size.y = 1560
		suffix = "-tall"
	elif OS.get_cmdline_user_args().has("--desktop"):
		canvas.size = Vector2i(450, 800)
		canvas.size_2d_override = Vector2i(720, 1280)
		canvas.size_2d_override_stretch = true
		suffix = "-desktop"
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(canvas)
	ui = load("res://scenes/main.tscn").instantiate()
	canvas.add_child(ui)
	ui._choose_starter(0)
	Profile.data.tutorial = true
	ui.show_screen("Setup")
	ui._start_battle()
	ui.get_node("AITimer").stop()
	baseline = ui.rules.state.duplicate(true)
	baseline.turn_count = 3
	baseline.energy_ready = true
	baseline.support_used = false
	baseline.retreat_used = false
	baseline.replacement = -1
	baseline.players[0].active = {"id": "ashmane", "hp": 80, "energy": 5, "boost": 0}
	baseline.players[0].bench = [{"id": "cinderhorn", "hp": 40, "energy": 3, "boost": 0}]
	baseline.players[0].hand = [
		"emberlyn", "dew_vial", "current_relay", "warcry_sigil", "scout_feather"
	]
	baseline.players[1].active = {"id": "cloudram", "hp": 100, "energy": 5, "boost": 0}
	baseline.players[1].bench = [{"id": "stormrook", "hp": 80, "energy": 0, "boost": 0}]
	for actor: int in range(2):
		reset(actor)
		await get_tree().process_frame
		await get_tree().process_frame
		var old_hp: int = ui.rules.state.players[1 - actor].active.hp
		var damage: int = ui.rules.damage_for(actor, 0)
		var old_view: Control = ui.get_node("BattleEffects").unit_view(
			ui.screen("Battle"), 1 - actor
		)
		var start: int = Time.get_ticks_msec()
		check(ui._apply_battle_action(actor, {"type": "attack", "attack": 0}), "attack accepted")
		check(ui.get_node("BattleEffects").busy, "presentation locks synchronously")
		check(
			ui.rules.state.players[1 - actor].active.hp == old_hp - damage,
			"damage committed immediately"
		)
		check(Profile.data.battle == ui.rules.state, "save committed before presentation")
		check(is_instance_valid(old_view), "old board retained during attack")
		var committed: Dictionary = ui.rules.state.duplicate(true)
		check(not ui._apply_battle_action(actor, {"type": "end"}), "repeated input rejected")
		ui._ai_step()
		check(
			ui.rules.state == committed and ui.get_node("AITimer").is_stopped(),
			"AI blocked during effects"
		)
		await get_tree().create_timer(0.25).timeout
		check(
			ui.get_node("BattleEffects/Message").text == "−%d" % damage, "actual damage displayed"
		)
		await capture("impact-%d" % actor)
		await finish()
		check(Time.get_ticks_msec() - start < 1000, "ordinary attack under one second")
	check(ui.rules.damage_for(0, 0) == 50, "Flame advantage includes twenty bonus damage")
	# Tide gets its own impact presentation as well.
	reset()
	ui.rules.state.players[0].active.id = "tidekit"
	ui._render_battle()
	ui._apply_battle_action(0, {"type": "attack", "attack": 0})
	await get_tree().create_timer(0.25).timeout
	await capture("tide")
	await finish()
	for action: Dictionary in [
		{"type": "attach", "target": 0},
		{"type": "deploy", "hand": 0},
		{"type": "support", "hand": 1, "target": 0},
		{"type": "support", "hand": 2, "target": 0},
		{"type": "support", "hand": 3, "target": -1},
		{"type": "support", "hand": 4, "target": -1},
		{"type": "retreat", "target": 0},
		{"type": "end"}
	]:
		reset()
		if action.type == "support" and action.hand == 1:
			ui.rules.state.players[0].bench[0].hp = Catalog.card("cinderhorn").max_hp - 5
		check(ui._apply_battle_action(0, action), "action accepted: " + str(action))
		if action.type == "support" and action.hand == 1:
			await get_tree().create_timer(0.25).timeout
			check(
				ui.get_node("BattleEffects/Message").text == "+5 HP",
				"actual capped healing displayed"
			)
		await finish()
		check(not ui.get_node("BattleEffects").busy, "action completes")
	reset()
	ui.rules.state.players[1].active.hp = 1
	ui._apply_battle_action(0, {"type": "attack", "attack": 0})
	await finish()
	check(
		ui.rules.state.replacement == 1 and ui.current_screen == "Battle",
		"knockout waits for replacement"
	)
	check(
		ui._apply_battle_action(1, {"type": "promote", "target": 0}), "promotion from empty active"
	)
	await finish()
	reset()
	ui.rules.state.players[0].points = 2
	ui.rules.state.players[1].active.hp = 1
	var start: int = Time.get_ticks_msec()
	ui._apply_battle_action(0, {"type": "attack", "attack": 0})
	check(ui.current_screen == "Battle", "finishing hit delays results")
	await finish()
	check(
		ui.current_screen == "Results" and Time.get_ticks_msec() - start < 1400,
		"finish under 1.4 seconds"
	)
	ui.show_screen("Results")
	check(not ui.get_node("BattleEffects").busy, "reopened results do not replay")
	for outcome: int in [1, -1]:
		reset()
		if outcome == 1:
			ui._apply_battle_action(0, {"type": "concede"})
		else:
			ui.rules.state.turn_count = 60
			ui._apply_battle_action(0, {"type": "end"})
		await get_tree().create_timer(0.25).timeout
		check(
			ui.get_node("BattleEffects/Message").text == ("DEFEAT" if outcome == 1 else "DRAW"),
			"distinct result flourish"
		)
		await finish()
		check(ui.current_screen == "Results", "result navigates after flourish")
	reset()
	ui._apply_battle_action(0, {"type": "attach", "target": -1})
	ui.show_screen("Home")
	check(not ui.get_node("BattleEffects").busy, "navigation cancels effects")
	ui.show_screen("Battle")
	check(
		not ui.get_node("BattleEffects").busy and not ui.rules.state.energy_ready,
		"resume renders committed state"
	)
	reset()
	ui._apply_battle_action(0, {"type": "attack", "attack": 0})
	ui.notification(NOTIFICATION_APPLICATION_PAUSED)
	check(not ui.get_node("BattleEffects").busy, "background cancels effects")
	ui.notification(NOTIFICATION_APPLICATION_RESUMED)
	ui.get_node("AITimer").stop()
	reset()
	var temporary: String = ProjectSettings.globalize_path(Profile.SAVE_PATH + ".tmp")
	DirAccess.make_dir_absolute(temporary)
	check(not ui._apply_battle_action(0, {"type": "attach", "target": -1}), "failed save rejected")
	check(
		not ui.get_node("BattleEffects").busy and ui.rules.state.energy_ready,
		"failed save has no effects"
	)
	DirAccess.remove_absolute(temporary)
	Profile.data.settings.battle_effects = false
	reset()
	ui._apply_battle_action(0, {"type": "attach", "target": -1})
	check(not ui.get_node("BattleEffects").busy, "disabled effects finish synchronously")
	var legacy: Dictionary = Profile.data.duplicate(true)
	legacy.settings.erase("battle_effects")
	var file: FileAccess = FileAccess.open("user://legacy.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var loaded: Dictionary = Profile._read_save("user://legacy.json")
	check(
		(
			loaded.settings.battle_effects
			and loaded.battle == JSON.parse_string(JSON.stringify(legacy.battle))
		),
		"legacy save retains progress and defaults effects"
	)
	check(Audio.voices.size() == 6 and Audio.streams.size() == 18, "bounded preloaded audio pool")
	Profile.data.settings.music = false
	Profile.data.settings.sfx = false
	Audio.apply_settings()
	Audio.play_cue("flame")
	check(
		not Audio.music.playing and not Audio.battle_music.playing, "music mute stops both tracks"
	)
	for voice: AudioStreamPlayer in Audio.voices:
		check(not voice.playing, "SFX muted")
	print("EFFECTS TESTS: %d checks, %d failures" % [checks, failures])
	Audio.shutdown()
	ui.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1 if failures else 0)
