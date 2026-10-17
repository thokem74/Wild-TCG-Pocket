extends Node

## Exercise real GUI event routing, not just CardView's signal handler.
var failures: int = 0
var checks: int = 0
var canvas: SubViewport
var ui: Control
var pointer_position: Vector2 = Vector2.ZERO


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("SCROLL TEST: " + message)


func _ready() -> void:
	await get_tree().process_frame
	Profile.data = Profile.fresh_data()
	canvas = SubViewport.new()
	canvas.size = (
		Vector2i(720, 1560) if OS.get_cmdline_user_args().has("--tall") else Vector2i(720, 1280)
	)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(canvas)
	ui = load("res://scenes/main.tscn").instantiate()
	canvas.add_child(ui)
	ui._choose_starter(0)
	ui.show_screen("Collection")
	await _settle()
	var scroll: ScrollContainer = ui.get_node("Safe/Layout/Scroll")
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	check(not bar.visible, "vertical scrollbar is hidden")
	check(
		scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER,
		"native invisible scrolling"
	)
	check(scroll.scroll_deadzone == 12, "vertical touch threshold")
	check(not scroll.get_h_scroll_bar().visible, "collection does not overflow horizontally")
	check(
		is_equal_approx(ui.screen("Collection").size.x, scroll.size.x),
		"collection reclaims scrollbar width"
	)
	for view: CardView in ui.screen("Collection").get_node("Grid").get_children():
		if Catalog.card(view.card_id).is_creature():
			var name_label: Label = view.get_node("Content/Header/Name")
			check(name_label.get_line_count() == 1, "creature name fits beside HP: " + view.card_id)
	await _capture("collection")

	var card: CardView = ui.screen("Collection").get_node("Grid").get_child(0)
	var point: Vector2 = card.get_global_rect().get_center()
	_mouse_motion(point)
	_mouse_button(point, MOUSE_BUTTON_WHEEL_DOWN, true)
	_mouse_button(point, MOUSE_BUTTON_WHEEL_DOWN, false)
	await _settle()
	check(scroll.scroll_vertical > 0, "wheel over a card reaches its scroll parent")
	check(ui.current_screen == "Collection", "wheel does not select a card")
	scroll.scroll_vertical = 0
	var pan: InputEventPanGesture = InputEventPanGesture.new()
	pan.position = point
	pan.delta = Vector2(0, 3)
	canvas.push_input(pan, true)
	await _settle()
	check(scroll.scroll_vertical > 0, "trackpad pan scrolls with hidden bars")
	scroll.scroll_vertical = 0
	await _settle()
	# The native ScrollContainer touch path is enabled on desktop for this test only.
	Input.emulate_touch_from_mouse = true
	scroll.scroll_vertical = 0
	await _settle()
	point = card.get_global_rect().get_center()
	await _swipe(point, point - Vector2(0, 160))
	check(scroll.scroll_vertical > 0, "touch swipe beginning on a card scrolls")
	check(ui.current_screen == "Collection", "touch swipe does not open a card")
	Input.emulate_touch_from_mouse = false
	scroll.scroll_vertical = 0
	await _settle()
	point = card.get_global_rect().get_center()
	_mouse_motion(point)
	_mouse_button(point, MOUSE_BUTTON_LEFT, true)
	check(ui.current_screen == "Collection", "routed mouse press waits for release")
	_mouse_button(point, MOUSE_BUTTON_LEFT, false)
	await _settle()
	check(ui.current_screen == "Detail", "routed mouse release opens card detail")

	ui.show_screen("Setup")
	Profile.data.tutorial = true
	ui._start_battle()
	ui.get_node("AITimer").stop()
	ui.rules.state.turn = 0
	ui.rules.state.turn_count = 3
	ui.rules.state.energy_ready = true
	ui._render_battle()
	await _settle()
	var hand: ScrollContainer = ui.screen("Battle").get_node("HandScroll")
	var hand_bar: HScrollBar = hand.get_h_scroll_bar()
	check(not hand_bar.visible, "horizontal scrollbar is hidden")
	check(
		hand.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER,
		"hand uses invisible native scrolling"
	)
	check(hand.scroll_deadzone == 12, "horizontal touch threshold")
	check(not scroll.visible, "battle is outside the page scroller")
	await _check_battle_layout("normal")
	await _capture("battle")
	var board_position: Vector2 = ui.screen("Battle").global_position
	_mouse_button(ui.screen("Battle").get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN, true)
	_mouse_button(
		ui.screen("Battle").get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN, false
	)
	await _settle()
	check(ui.screen("Battle").global_position == board_position, "battle cannot scroll vertically")
	hand.scroll_horizontal = 0
	await _settle()
	var hand_card: CardView = hand.get_node("Hand").get_child(0)
	point = hand_card.get_global_rect().get_center()
	Input.emulate_touch_from_mouse = true
	await _swipe(point, point - Vector2(120, 0))
	check(hand.scroll_horizontal > 0, "touch swipe beginning on a hand card scrolls")
	check(ui.selected_hand == -1, "hand swipe does not select a battle card")
	Input.emulate_touch_from_mouse = false
	await _battle_scenarios()
	print("SCROLL TESTS: %d checks, %d failures" % [checks, failures])
	Audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1 if failures else 0)


func _check_battle_layout(label: String) -> void:
	await _settle()
	var battle: Control = ui.screen("Battle")
	var nav: Control = ui.get_node("Safe/Layout/Nav")
	check(
		battle.get_global_rect().end.y <= nav.global_position.y,
		label + ": board fits above navigation"
	)
	check(nav.get_global_rect().end.y <= canvas.size.y, label + ": navigation fits viewport")
	for child: Control in battle.get_children():
		check(
			battle.get_global_rect().encloses(child.get_global_rect()),
			label + ": visible " + child.name
		)
	for parent_name: String in ["Actions", "Attacks", "Bottom", "Selection"]:
		for child: Control in battle.get_node(parent_name).get_children():
			check(
				battle.get_global_rect().encloses(child.get_global_rect()),
				label + ": reachable " + child.name
			)


func _battle_scenarios() -> void:
	var battle: Node = ui.screen("Battle")
	var player: Dictionary = ui.rules.state.players[0]
	player.active = {"id": "ashmane", "hp": 80, "energy": 2, "boost": 0}
	player.bench = []
	for id: String in ["aurelion", "thornsprite", "cinderhorn"]:
		player.bench.append({"id": id, "hp": Catalog.card(id).max_hp - 10, "energy": 2, "boost": 0})
	ui.rules.state.players[1].bench = player.bench.duplicate(true)
	player.hand = ["dew_vial", "current_relay"]
	for index: int in range(16):
		player.hand.append("thornsprite")
	ui.rules.state.energy_ready = true
	ui._render_battle()
	ui._select_hand(0)
	await _check_battle_layout("four support targets and two attacks")
	for button: Button in battle.get_node("Actions").get_children():
		check(not button.disabled, "all four heal targets accessible")
	for button: Button in battle.get_node("Attacks").get_children():
		check(not button.disabled, "both attacks accessible")
	await _capture("full-actions")
	var layout_height: float = battle.size.y
	ui._select_hand(1)
	check(
		battle.get_node("Actions/Action0").text.begins_with("Move from"),
		"energy relay identifies donor"
	)
	ui._select_unit(0)
	check(
		battle.get_node("Actions/Action1").text.begins_with("Retreat"),
		"retreat reachable beside attachment"
	)
	await _check_battle_layout("bench actions")
	# Repeated selection must replace button callbacks rather than accumulate them.
	var saved_state: Dictionary = ui.rules.state.duplicate(true)
	ui._select_unit(0)
	ui._select_unit(0)
	battle.get_node("Actions/Action0").pressed.emit()
	check(
		int(ui.rules.state.players[0].bench[0].energy) == 3 and not ui.rules.state.energy_ready,
		"context slot attaches once to selected bench"
	)
	ui._select_hand(0)
	battle.get_node("Actions/Action2").pressed.emit()
	check(
		(
			ui.rules.state.support_used
			and int(ui.rules.state.players[0].bench[1].hp) == Catalog.card("thornsprite").max_hp
		),
		"reused context slot plays support on chosen target"
	)
	ui.rules.state = saved_state
	ui._render_battle()
	ui._select_hand(0)
	var before: Dictionary = ui.rules.state.duplicate(true)
	ui._inspect_selection()
	check(
		ui.current_screen == "Battle" and ui.get_node("BattleOverlay").visible,
		"battle inspection is an overlay"
	)
	check(ui.get_node("AITimer").is_stopped(), "inspection stops AI")
	ui.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	ui.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(
		ui.current_screen == "Battle" and not ui.get_node("BattleOverlay").visible,
		"duplicate Android Back dismisses only the overlay"
	)
	check(ui.selected_hand == 0 and ui.selected_mode == "hand", "Back preserves selected hand card")
	check(ui.rules.state == before, "inspection does not change battle state")
	for id: String in Catalog.cards:
		ui._inspect_battle_card(id)
		await _settle()
		var overlay: Control = ui.get_node("BattleOverlay")
		check(
			overlay.get_global_rect().encloses(
				ui.get_node("BattleOverlay/Content/Close").get_global_rect()
			),
			"inspection fits: " + id
		)
	ui._close_battle_overlay()
	ui.rules.state.log = []
	for index: int in range(25):
		ui.rules.state.log.append(
			"Guardian %d attacks the rival and earns a knockout point." % index
		)
	ui._show_history()
	check(ui.history_page == 6, "history opens newest page")
	ui._change_history_page(-1)
	check(ui.history_page == 5, "history previous page")
	ui._change_history_page(-100)
	check(ui.get_node("BattleOverlay/Content/Pages/Previous").disabled, "history clamps first page")
	ui._change_history_page(100)
	check(ui.get_node("BattleOverlay/Content/Pages/Next").disabled, "history clamps last page")
	await _capture("history")
	ui._close_battle_overlay()
	ui.rules.state.turn_count = 1
	ui.rules.state.energy_ready = false
	ui._render_battle()
	await _check_battle_layout("first turn restrictions")
	check(is_equal_approx(layout_height, battle.size.y), "empty actions preserve board height")
	for button: Button in battle.get_node("Attacks").get_children():
		check(button.disabled, "first turn has no attack")
	ui.rules.state.replacement = 0
	ui._render_battle()
	await _check_battle_layout("replacement")
	check(not battle.get_node("Actions/Action2").disabled, "three promotions accessible")
	ui.rules.state.replacement = -1
	ui.rules.state.turn = 1
	ui.rules.state.turn_count = 4
	ui._render_battle()
	ui._inspect_battle_card("ashmane")
	before = ui.rules.state.duplicate(true)
	ui._ai_step()
	check(ui.rules.state == before, "AI cannot move behind inspection")
	ui._close_battle_overlay()
	check(not ui.get_node("AITimer").is_stopped(), "closing inspection resumes AI")
	ui.get_node("AITimer").stop()
	ui._show_history()
	ui._ai_step()
	check(ui.rules.state == before, "AI cannot move behind history")
	ui._close_battle_overlay()
	ui.get_node("AITimer").stop()
	ui.show_screen("Home")
	ui.show_screen("Battle")
	ui.get_node("AITimer").stop()
	check(ui.rules.state == before, "leaving and returning preserves battle")
	ui.rules.state.turn = 0
	ui._render_battle()
	ui.get_node("Safe").add_theme_constant_override("margin_top", 58)
	ui.get_node("Safe").add_theme_constant_override("margin_bottom", 38)
	await _check_battle_layout("Android safe area")


func _mouse_button(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	pointer_position = point
	event.button_index = button
	event.pressed = pressed
	canvas.push_input(event, true)


func _mouse_motion(point: Vector2, held: bool = false) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - pointer_position
	pointer_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	canvas.push_input(event, true)


func _swipe(start: Vector2, finish: Vector2) -> void:
	var press: InputEventScreenTouch = InputEventScreenTouch.new()
	press.position = start
	press.pressed = true
	canvas.push_input(press, true)
	_mouse_button(start, MOUSE_BUTTON_LEFT, true)
	await _settle()
	var previous: Vector2 = start
	for step: int in range(1, 6):
		var point: Vector2 = start.lerp(finish, step / 5.0)
		var drag: InputEventScreenDrag = InputEventScreenDrag.new()
		drag.position = point
		drag.relative = point - previous
		canvas.push_input(drag, true)
		_mouse_motion(point, true)
		previous = point
		await _settle()
	press = InputEventScreenTouch.new()
	press.position = finish
	press.pressed = false
	canvas.push_input(press, true)
	_mouse_button(finish, MOUSE_BUTTON_LEFT, false)
	await _settle()


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://builds/previews")
	var suffix: String = "-tall" if OS.get_cmdline_user_args().has("--tall") else ""
	canvas.get_texture().get_image().save_png(
		"res://builds/previews/scroll-%s%s.png" % [label, suffix]
	)
