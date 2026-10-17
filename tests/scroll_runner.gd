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
	check(is_equal_approx(bar.size.x, 36.0), "vertical scrollbar has a 36 px hit width")
	check(
		bar.get_theme_stylebox("grabber").get_minimum_size().y >= 80.0,
		"vertical handle minimum length"
	)
	check(scroll.scroll_deadzone == 12, "vertical touch threshold")
	check(scroll.get_theme_constant("scrollbar_v_separation") == 8, "content gap")
	check(not scroll.get_h_scroll_bar().visible, "collection does not overflow horizontally")
	check(
		ui.screen("Collection").size.x <= scroll.size.x - 36.0 - 8.0,
		"three card columns fit beside bar"
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
	await _settle()
	var handle_point: Vector2 = bar.global_position + Vector2(18, 60)
	_mouse_motion(handle_point)
	await _settle()
	await _capture("hover")
	_mouse_button(handle_point, MOUSE_BUTTON_LEFT, true)
	await _settle()
	await _capture("pressed")
	_mouse_motion(handle_point + Vector2(0, 220), true)
	_mouse_button(handle_point + Vector2(0, 220), MOUSE_BUTTON_LEFT, false)
	await _settle()
	check(scroll.scroll_vertical > 0, "dragging vertical handle moves content")
	scroll.scroll_vertical = 0
	await _settle()
	var track_point: Vector2 = bar.global_position + Vector2(18, bar.size.y - 60)
	_mouse_motion(track_point)
	_mouse_button(track_point, MOUSE_BUTTON_LEFT, true)
	_mouse_button(track_point, MOUSE_BUTTON_LEFT, false)
	await _settle()
	check(scroll.scroll_vertical > 0, "clicking vertical track pages content")

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
	check(is_equal_approx(hand_bar.size.y, 36.0), "horizontal scrollbar has a 36 px hit height")
	check(
		hand_bar.get_theme_stylebox("grabber").get_minimum_size().x >= 80.0,
		"horizontal handle minimum length"
	)
	check(hand.scroll_deadzone == 12, "horizontal touch threshold")
	# Make the horizontal scrollbar visible in the shared screen's clipping rectangle.
	scroll.scroll_vertical = maxi(0, int(hand.position.y - 350))
	await _settle()
	await _capture("battle")
	var hand_point: Vector2 = hand_bar.global_position + Vector2(60, 18)
	_mouse_motion(hand_point)
	_mouse_button(hand_point, MOUSE_BUTTON_LEFT, true)
	_mouse_motion(hand_point + Vector2(120, 0), true)
	_mouse_button(hand_point + Vector2(120, 0), MOUSE_BUTTON_LEFT, false)
	await _settle()
	check(hand.scroll_horizontal > 0, "dragging horizontal handle moves hand")
	hand.scroll_horizontal = 0
	await _settle()
	var hand_card: CardView = hand.get_node("Hand").get_child(0)
	point = hand_card.get_global_rect().get_center()
	Input.emulate_touch_from_mouse = true
	await _swipe(point, point - Vector2(120, 0))
	check(hand.scroll_horizontal > 0, "touch swipe beginning on a hand card scrolls")
	check(ui.selected_hand == -1, "hand swipe does not select a battle card")
	Input.emulate_touch_from_mouse = false
	print("SCROLL TESTS: %d checks, %d failures" % [checks, failures])
	Audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1 if failures else 0)


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
