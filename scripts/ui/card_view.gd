class_name CardView
extends PanelContainer

signal selected

const TAP_DRAG_THRESHOLD: float = 12.0

static var textures: Dictionary = {}

var card_id: String = ""
var _tap_pending: bool = false
var _press_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_exited.connect(_cancel_tap)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func configure(id: String, owned: int = -1, unit: Dictionary = {}, compact: bool = false) -> void:
	card_id = id
	var card: CardDefinition = Catalog.card(id)
	$Content/Header/Name.text = card.display_name
	$Content/Header/HP.text = (
		"%d HP" % int(unit.get("hp", card.max_hp)) if card.is_creature() else "✦"
	)
	$Content/Element.text = "%s  /  %s" % [card.element.to_upper(), card.rarity.to_upper()]
	$Content/Element.modulate = Catalog.COLORS[card.element]
	$Content/Rules.text = card.rules_text
	$Content/Footer.text = (
		"WILD • FIRST LIGHT"
		if owned < 0
		else ("Owned ×%d" % owned if owned > 0 else "UNDISCOVERED")
	)
	if not unit.is_empty():
		$Content/Footer.text = "%d ENERGY  •  RETREAT %d" % [int(unit.energy), card.retreat_cost]
	var frame: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	frame.border_color = Catalog.COLORS[card.element].lightened(0.4)
	frame.border_width_bottom = 5 if card.rarity in ["Rare", "Legendary"] else 2
	add_theme_stylebox_override("panel", frame)
	if ResourceLoader.exists(card.art_path):
		if not textures.has(card.art_path):
			textures[card.art_path] = load(card.art_path)
		$Content/Art.texture = textures[card.art_path]
	if compact:
		custom_minimum_size = Vector2(200, 228)
		$Content/Art.custom_minimum_size.y = 100
		$Content/Rules.visible = false
	if owned == 0:
		modulate = Color(0.7, 0.74, 0.83, 1)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _tap_pending and event.global_position.distance_to(_press_position) > TAP_DRAG_THRESHOLD:
			_cancel_tap()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_tap_pending = not event.canceled
			_press_position = event.global_position
			# Let the enclosing ScrollContainer observe the press and start a swipe.
			return
		var is_tap: bool = (
			_tap_pending
			and not event.canceled
			and event.global_position.distance_to(_press_position) <= TAP_DRAG_THRESHOLD
			and Rect2(Vector2.ZERO, size).has_point(event.position)
		)
		_cancel_tap()
		if is_tap:
			selected.emit()
			accept_event()


func _cancel_tap() -> void:
	_tap_pending = false


func _notification(what: int) -> void:
	# Native touch scrolling can take over before emulated mouse motion arrives.
	if what == NOTIFICATION_SCROLL_BEGIN or what == NOTIFICATION_APPLICATION_PAUSED:
		_cancel_tap()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_cancel_tap()
