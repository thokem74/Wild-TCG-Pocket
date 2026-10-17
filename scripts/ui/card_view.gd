class_name CardView
extends PanelContainer

signal selected

var card_id: String = ""
static var textures: Dictionary = {}


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
	gui_input.connect(_on_gui_input)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit()
		accept_event()
