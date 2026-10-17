extends "res://tests/scroll_runner.gd"

## Reuse the native GUI input helpers so taps exercise the real card signal wiring.
var baseline: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	Profile.data = Profile.fresh_data()
	canvas = SubViewport.new()
	canvas.size = (
		Vector2i(720, 1560) if OS.get_cmdline_user_args().has("--tall") else Vector2i(720, 1280)
	)
	if OS.get_cmdline_user_args().has("--desktop"):
		canvas.size = Vector2i(450, 800)
		canvas.size_2d_override = Vector2i(720, 1280)
		canvas.size_2d_override_stretch = true
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
	baseline.turn = 0
	baseline.turn_count = 3
	baseline.energy_ready = true
	baseline.replacement = -1
	baseline.support_used = false
	baseline.retreat_used = false
	baseline.players[0].active = {"id": "ashmane", "hp": 80, "energy": 2, "boost": 20}
	baseline.players[0].bench = [
		{"id": "cinderhorn", "hp": 60, "energy": 2, "boost": 0},
		{"id": "thornsprite", "hp": 90, "energy": 2, "boost": 0},
	]
	baseline.players[0].hand = ["emberlyn", "dew_vial", "current_relay", "warcry_sigil"]
	baseline.players[1].active = {"id": "cloudram", "hp": 100, "energy": 1, "boost": 0}
	baseline.players[1].bench = [{"id": "stormrook", "hp": 80, "energy": 0, "boost": 0}]

	_reset_battle()
	await _settle()
	var active: CardView = ui.screen("Battle").get_node("Actives/YourActive/Card").get_child(0)
	await _tap(active)
	check(ui.get_node("BattleOverlay").visible, "own active tap opens overview")
	check(
		ui.selected_target == -1 and ui.selected_mode == "unit", "active selected before overview"
	)
	var text: String = ui.get_node("BattleOverlay/Content/Text").text
	check(
		(
			text.contains("80 / 100 HP")
			and text.contains("2 energy")
			and text.contains("+20 this turn")
		),
		"overview shows live stats"
	)
	check(ui._overview_actions().size() == 3, "active offers attach and two attacks")
	await _check_overview_fit("active")
	await _capture_overview("active")
	ui.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	ui.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(
		ui.current_screen == "Battle" and not ui.get_node("BattleOverlay").visible,
		"duplicate Back closes only overview"
	)

	await _tap(ui.screen("Battle").get_node("YourBench").get_child(0))
	check(
		ui.get_node("BattleOverlay").visible and ui.selected_target == 0,
		"bench tap opens selected overview"
	)
	check(ui._overview_actions().size() == 2, "bench offers only attachment and retreat")
	_press_overview_action("retreat")
	await _finish_effects()
	check(ui.rules.state.players[0].active.id == "cinderhorn", "overview retreat uses chosen bench")
	check(not ui.get_node("BattleOverlay").visible, "successful action closes overview")
	check(Profile.data.battle == ui.rules.state, "successful action persisted")

	_reset_battle()
	await _settle()
	await _tap(ui.screen("Battle").get_node("HandScroll/Hand").get_child(0))
	check(
		ui.selected_hand == 0 and ui.get_node("BattleOverlay").visible,
		"hand tap opens selected overview"
	)
	check(ui._overview_actions().size() == 1, "hand creature offers only deployment")
	_press_overview_action("deploy")
	await _finish_effects()
	check(ui.rules.state.players[0].bench.size() == 3, "overview deploys creature")

	_reset_battle()
	ui.rules.state.players[0].bench.append({"id": "aurelion", "hp": 100, "energy": 1, "boost": 0})
	ui._render_battle()
	ui._open_hand_overview(1)
	check(ui._overview_actions().size() == 4, "healing support offers all four targets")
	await _check_overview_fit("four support targets")
	await _capture_overview("support")
	_press_overview_action("support", 1)
	await _finish_effects()
	check(
		int(ui.rules.state.players[0].bench[1].hp) == 110 and ui.rules.state.support_used,
		"overview support heals chosen ally"
	)
	_reset_battle()
	ui._open_hand_overview(2)
	check(str(ui._overview_actions()[0].text).begins_with("Move from"), "relay labels donor")
	_press_overview_action("support", 0)
	await _finish_effects()
	check(
		(
			int(ui.rules.state.players[0].active.energy) == 3
			and int(ui.rules.state.players[0].bench[0].energy) == 1
		),
		"overview moves existing donor energy"
	)

	_reset_battle()
	ui._open_unit_overview(-1)
	_press_overview_action("attack")
	await _finish_effects()
	check(
		int(ui.rules.state.players[1].active.hp) == 30,
		"overview attack includes boost and weakness"
	)
	check(
		int(ui.rules.state.turn) == 1 and not ui.get_node("BattleOverlay").visible,
		"attack closes overview and ends turn"
	)
	ui.get_node("AITimer").stop()

	_reset_battle()
	ui.rules.state.replacement = 0
	ui.rules.state.players[0].active = {}
	ui._render_battle()
	ui._open_unit_overview(1)
	check(ui._overview_actions().size() == 1, "replacement offers only chosen promotion")
	_press_overview_action("promote")
	await _finish_effects()
	check(
		ui.rules.state.players[0].active.id == "thornsprite",
		"overview promotes selected replacement"
	)

	_reset_battle()
	ui.rules.state.turn_count = 1
	ui.rules.state.energy_ready = false
	ui._render_battle()
	ui._open_unit_overview(-1)
	check(
		not ui.get_node("BattleOverlay/Content/Actions").visible,
		"no-action card still opens overview"
	)
	ui._close_battle_overlay()
	ui._select_hand(0)
	await _settle()
	await _tap(ui.screen("Battle").get_node("Actives/EnemyActive/Card").get_child(0))
	check(
		(
			ui.get_node("BattleOverlay").visible
			and not ui.get_node("BattleOverlay/Content/Actions").visible
		),
		"enemy remains view-only despite own selection"
	)
	check(
		ui.get_node("BattleOverlay/Content/Text").text.contains("100 / 100 HP"),
		"enemy overview shows live stats"
	)
	ui._close_battle_overlay()
	await _tap(ui.screen("Battle").get_node("EnemyBench").get_child(0))
	check(
		(
			ui.get_node("BattleOverlay/Content/Title").text == "Stormrook"
			and not ui.get_node("BattleOverlay/Content/Actions").visible
		),
		"enemy bench remains view-only"
	)

	_reset_battle()
	ui._open_unit_overview(-1)
	var before: Dictionary = ui.rules.state.duplicate(true)
	ui._perform_overview_action({"type": "attach", "target": 99})
	check(
		ui.rules.state == before and ui.get_node("BattleOverlay").visible,
		"stale action leaves overview and battle unchanged"
	)
	check(
		ui.get_node("BattleOverlay/Content/Error").visible,
		"stale action error appears inside overview"
	)
	# A directory at the temporary save path deterministically simulates unwritable storage.
	var temporary: String = ProjectSettings.globalize_path(Profile.SAVE_PATH + ".tmp")
	check(DirAccess.make_dir_absolute(temporary) == OK, "create isolated save failure fixture")
	var saved: Dictionary = Profile.data.battle.duplicate(true)
	_press_overview_action("attach")
	await _finish_effects()
	check(
		ui.rules.state == before and Profile.data.battle == saved,
		"save failure rolls back both battle copies"
	)
	check(
		ui.get_node("BattleOverlay").visible and ui.get_node("BattleOverlay/Content/Error").visible,
		"save failure stays visible in overview"
	)
	check(not ui.get_node("Safe/Layout/Toast").visible, "overview error does not resize board")
	await _check_overview_fit("save error")
	check(DirAccess.remove_absolute(temporary) == OK, "remove isolated save failure fixture")
	_press_overview_action("attach")
	await _finish_effects()
	check(
		not ui.get_node("BattleOverlay").visible and not ui.rules.state.energy_ready,
		"retry commits once and closes overview"
	)

	_reset_battle()
	ui.rules.state.turn = 1
	ui._render_battle()
	ui._open_hand_overview(0)
	before = ui.rules.state.duplicate(true)
	ui._ai_step()
	check(
		ui.rules.state == before and ui.get_node("AITimer").is_stopped(),
		"own overview blocks AI during rival turn"
	)
	check(
		not ui.get_node("BattleOverlay/Content/Actions").visible,
		"rival turn exposes no own actions"
	)
	ui._close_battle_overlay()
	check(not ui.get_node("AITimer").is_stopped(), "closing overview resumes rival")
	ui.get_node("AITimer").stop()
	await _all_cards_fit()
	print("OVERVIEW TESTS: %d checks, %d failures" % [checks, failures])
	Audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1 if failures else 0)


func _reset_battle() -> void:
	ui.rules.state = baseline.duplicate(true)
	Profile.data.battle = baseline.duplicate(true)
	ui.selected_mode = "unit"
	ui.selected_target = -1
	ui.selected_hand = -1
	ui.get_node("BattleOverlay").hide()
	ui.get_node("ModalBlocker").hide()
	ui._render_battle()
	ui.get_node("AITimer").stop()


func _tap(control: Control) -> void:
	await _settle()
	var point: Vector2 = control.get_global_rect().get_center()
	_mouse_motion(point)
	_mouse_button(point, MOUSE_BUTTON_LEFT, true)
	_mouse_button(point, MOUSE_BUTTON_LEFT, false)
	await _settle()


func _press_overview_action(kind: String, target: int = -99) -> void:
	var actions: Array[Dictionary] = ui._overview_actions()
	for index: int in range(actions.size()):
		var action: Dictionary = actions[index].action
		if action.type == kind and (target == -99 or int(action.get("target", -99)) == target):
			ui.get_node("BattleOverlay/Content/Actions").get_child(index).pressed.emit()
			return
	check(false, "missing overview action: " + kind)


func _check_overview_fit(label: String) -> void:
	await _settle()
	var overlay: Control = ui.get_node("BattleOverlay")
	check(
		ui.get_global_rect().encloses(overlay.get_global_rect()), label + ": overlay fits viewport"
	)
	for child: Control in ui.get_node("BattleOverlay/Content").get_children():
		if child.visible:
			check(
				overlay.get_global_rect().encloses(child.get_global_rect()),
				label + ": fits " + child.name
			)
	var grid: Control = ui.get_node("BattleOverlay/Content/Actions")
	if grid.visible:
		check(
			(
				ui.get_node("BattleOverlay/Content/Text").get_global_rect().end.y
				<= grid.global_position.y
			),
			label + ": text above actions"
		)
		check(
			(
				grid.get_global_rect().end.y
				<= ui.get_node("BattleOverlay/Content/Close").global_position.y
			),
			label + ": actions above close"
		)


func _all_cards_fit() -> void:
	for id: String in Catalog.ordered_ids:
		_reset_battle()
		var card: CardDefinition = Catalog.card(id)
		if card.is_creature():
			ui.rules.state.players[0].active = {
				"id": id, "hp": card.max_hp - 10, "energy": 3, "boost": 20
			}
			ui._render_battle()
			ui._open_unit_overview(-1)
		else:
			ui.rules.state.players[0].hand[0] = id
			ui._render_battle()
			ui._open_hand_overview(0)
		await _check_overview_fit(id)


func _capture_overview(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://builds/previews")
	var suffix: String = (
		"-desktop"
		if OS.get_cmdline_user_args().has("--desktop")
		else ("-tall" if OS.get_cmdline_user_args().has("--tall") else "")
	)
	canvas.get_texture().get_image().save_png(
		"res://builds/previews/overview-%s%s.png" % [label, suffix]
	)


func _finish_effects() -> void:
	if ui.get_node("BattleEffects").busy:
		await ui.get_node("BattleEffects").finished
	ui.get_node("AITimer").stop()
