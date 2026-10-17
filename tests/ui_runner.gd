extends Node

var failures: int = 0


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _ready() -> void:
	await get_tree().process_frame
	Profile.data = Profile.fresh_data()
	var ui: Control = load("res://scenes/main.tscn").instantiate()
	add_child(ui)
	check(ui.current_screen == "Home", "new player starts at home")
	check(not get_tree().quit_on_go_back, "Android automatic Back quit disabled")
	ui.screen("Home").get_node("Starters/Tide").pressed.emit()
	check(int(Profile.data.starter) == 1, "starter button works")
	ui.show_screen("Packs")
	ui.screen("Packs").get_node("Open").pressed.emit()
	check(
		Profile.data.pending_pack.size() == 5 and int(Profile.data.reveal_index) == 1,
		"open/reveal workflow"
	)
	ui.screen("Packs").get_node("Skip").pressed.emit()
	ui.screen("Packs").get_node("Done").pressed.emit()
	check(ui.current_screen == "Collection", "finish pack reaches collection")
	ui.screen("Collection").get_node("Search").text = "Pearlfin"
	ui._render_collection()
	check(ui.screen("Collection").get_node("Grid").get_child_count() == 1, "collection search")
	var card: CardView = ui.screen("Collection").get_node("Grid").get_child(0)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	card.gui_input.emit(click)
	check(ui.current_screen == "Detail", "card mouse/touch emulation opens detail")
	ui.screen("Detail").get_node("Back").pressed.emit()
	check(ui.current_screen == "Collection", "detail back")
	ui.show_screen("Decks")
	var id: String = ui.draft[0]
	ui._change_deck(id, -1)
	ui._inspect(id)
	ui.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(ui.current_screen == "Decks", "Android Back returns to deck editor")
	check(ui.draft.size() == 19, "inspection preserves deck draft")
	ui._change_deck(id, 1)
	ui.screen("Decks").get_node("Name").text = "Test guardians"
	ui._save_deck()
	check(Profile.data.decks[0].name == "Test guardians", "save deck")
	ui.show_screen("Setup")
	ui._start_battle()
	check(
		ui.get_node("Modal").visible and ui.get_node("ModalBlocker").visible,
		"tutorial blocks background"
	)
	ui._confirm_modal()
	check(Profile.data.tutorial, "tutorial completed")
	ui.get_node("AITimer").stop()
	ui.rules.state.turn = 0
	ui.rules.state.turn_count = 3
	ui.rules.state.energy_ready = true
	ui.rules.state.players[0].active.energy = 2
	ui._render_battle()
	ui._perform({"type": "attach", "target": -1})
	check(not ui.rules.state.energy_ready, "UI energy action")
	ui._perform({"type": "concede"})
	check(
		ui.current_screen == "Results" and int(Profile.data.coins) == 0,
		"concede results and no reward"
	)
	print("UI TESTS: %d failures" % failures)
	Profile.data = Profile.fresh_data()
	Profile.save()
	Audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1 if failures > 0 else 0)
