extends Control

const CARD_SCENE: PackedScene = preload("res://scenes/ui/card.tscn")
const BATTLE_CARD_SCENE: PackedScene = preload("res://scenes/ui/battle_card.tscn")
const ROW_SCENE: PackedScene = preload("res://scenes/ui/deck_row.tscn")
const HISTORY_PAGE_SIZE: int = 4
const BACK_REQUEST_INTERVAL_MS: int = 200
const SLOT_SCENE: PackedScene = preload("res://scenes/ui/board_slot.tscn")
var current_screen: String = ""
var previous_screen: String = "Collection"
var rules: BattleRules = BattleRules.new()
var draft: Array = []
var draft_index: int = 0
var selected_target: int = -1
var selected_hand: int = -1
var selected_mode: String = "unit"
var modal_callback: Callable
var reveal_tween: Tween
var history_page: int = 0
var _last_back_request_ms: int = -BACK_REQUEST_INTERVAL_MS

@onready var screens: VBoxContainer = $Safe/Layout/Scroll/Screens


func _ready() -> void:
	get_tree().auto_accept_quit = false
	# Android Back should navigate our screens rather than trigger SceneTree.quit().
	get_tree().quit_on_go_back = false
	Profile.changed.connect(_refresh_header)
	_wire_navigation()
	_wire_screens()
	$AITimer.timeout.connect(_ai_step)
	$BattleOverlay/Content/Close.pressed.connect(_close_battle_overlay)
	$BattleOverlay/Content/Pages/Previous.pressed.connect(_change_history_page.bind(-1))
	$BattleOverlay/Content/Pages/Next.pressed.connect(_change_history_page.bind(1))
	screen("Battle").get_node("Selection/Inspect").pressed.connect(_inspect_selection)
	screen("Battle").get_node("Selection/History").pressed.connect(_show_history)
	$Modal/Content/Buttons/OK.pressed.connect(_confirm_modal)
	$Modal/Content/Buttons/Cancel.pressed.connect(_dismiss_modal)
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()
	var hero: TextureRect = screen("Home").get_node("Hero/Art")
	if ResourceLoader.exists("res://assets/cards/aurelion.png"):
		hero.texture = load("res://assets/cards/aurelion.png")
	elif ResourceLoader.exists("res://assets/cards/emberlyn.png"):
		hero.texture = load("res://assets/cards/emberlyn.png")
	if not Profile.data.battle.is_empty():
		rules.state = Profile.data.battle.duplicate(true)
	show_screen("Packs" if not Profile.data.pending_pack.is_empty() else "Home")


func _refresh_header() -> void:
	$Safe/Layout/Header/Balance.text = (
		"%d COINS  ·  %d / 48" % [int(Profile.data.coins), Profile.data.owned.size()]
	)


func screen(screen_name: String) -> Node:
	if screen_name == "Battle":
		return $Safe/Layout/Battle
	return screens.get_node(screen_name)


func _wire_navigation() -> void:
	for button: Button in $Safe/Layout/Nav.get_children():
		button.pressed.connect(show_screen.bind(button.name))


func _wire_screens() -> void:
	var home: Node = screen("Home")
	for index: int in range(3):
		home.get_node("Starters/" + Catalog.ELEMENTS[index]).pressed.connect(
			_choose_starter.bind(index)
		)
	home.get_node("Packs").pressed.connect(show_screen.bind("Packs"))
	home.get_node("Battle").pressed.connect(show_screen.bind("Setup"))
	home.get_node("Resume").pressed.connect(_resume_battle)
	var packs: Node = screen("Packs")
	packs.get_node("Open").pressed.connect(_open_pack)
	packs.get_node("Next").pressed.connect(_reveal_next)
	packs.get_node("Skip").pressed.connect(_skip_reveal)
	packs.get_node("Done").pressed.connect(_finish_pack)
	var collection: Node = screen("Collection")
	for element: String in ["All elements", "Flame", "Tide", "Gale", "Support"]:
		collection.get_node("Filters/Element").add_item(element)
	for rarity: String in ["All rarities", "Common", "Uncommon", "Rare", "Legendary"]:
		collection.get_node("Filters/Rarity").add_item(rarity)
	for ownership: String in ["All cards", "Owned", "Missing"]:
		collection.get_node("Filters/Ownership").add_item(ownership)
	for filter_name: String in ["Element", "Rarity", "Ownership"]:
		collection.get_node("Filters/" + filter_name).item_selected.connect(
			func(_index: int) -> void: _render_collection()
		)
	collection.get_node("Search").text_changed.connect(
		func(_text: String) -> void: _render_collection()
	)
	screen("Detail").get_node("Back").pressed.connect(func() -> void: show_screen(previous_screen))
	var decks: Node = screen("Decks")
	decks.get_node("Selector").item_selected.connect(_load_draft)
	decks.get_node("Tools/New").pressed.connect(_new_deck)
	decks.get_node("Tools/Save").pressed.connect(_save_deck)
	screen("Setup").get_node("Difficulty").add_item("Easy • learning rival")
	screen("Setup").get_node("Difficulty").add_item("Normal • balanced rival")
	screen("Setup").get_node("Difficulty").add_item("Hard • tactical rival")
	screen("Setup").get_node("Difficulty").select(1)
	screen("Setup").get_node("Start").pressed.connect(_start_battle)
	screen("Battle").get_node("Bottom/End").pressed.connect(_perform.bind({"type": "end"}))
	screen("Battle").get_node("Bottom/Concede").pressed.connect(_ask_concede)
	screen("Results").get_node("Again").pressed.connect(show_screen.bind("Setup"))
	screen("Results").get_node("Home").pressed.connect(show_screen.bind("Home"))
	for key: String in ["Music", "SFX", "Animations"]:
		screen("Settings").get_node(key).toggled.connect(_setting_changed.bind(key.to_lower()))


func show_screen(screen_name: String) -> void:
	var returning_from_detail: bool = current_screen == "Detail"
	if int(Profile.data.starter) < 0 and screen_name != "Settings":
		screen_name = "Home"
	for child: Control in screens.get_children():
		child.visible = child.name == screen_name
	$Safe/Layout/Scroll.visible = screen_name != "Battle"
	$Safe/Layout/Battle.visible = screen_name == "Battle"
	$BattleOverlay.hide()
	$ModalBlocker.visible = $Modal.visible
	current_screen = screen_name
	$Safe/Layout/Scroll.scroll_vertical = 0
	$Safe/Layout/Header/Balance.text = (
		"%d COINS  ·  %d / 48" % [int(Profile.data.coins), Profile.data.owned.size()]
	)
	$Safe/Layout/Toast.hide()
	$AITimer.stop()
	Audio.play_cue()
	match screen_name:
		"Home":
			_render_home()
		"Packs":
			_render_pack()
		"Collection":
			_render_collection()
		"Decks":
			if returning_from_detail:
				_render_deck()
			else:
				_load_draft(mini(int(Profile.data.selected_deck), Profile.data.decks.size() - 1))
		"Setup":
			_render_setup()
		"Battle":
			_render_battle()
		"Results":
			_render_results()
		"Settings":
			for key: String in ["Music", "SFX", "Animations"]:
				screen("Settings").get_node(key).set_pressed_no_signal(
					Profile.data.settings[key.to_lower()]
				)


func _render_home() -> void:
	var home: Node = screen("Home")
	var needs_starter: bool = int(Profile.data.starter) < 0
	for node_name: String in ["Starters", "StarterTitle", "StarterNote"]:
		home.get_node(node_name).visible = needs_starter
	home.get_node("Packs").visible = not needs_starter
	home.get_node("Battle").visible = not needs_starter
	home.get_node("Resume").visible = not Profile.data.battle.is_empty()
	home.get_node("Stats").text = (
		"%d / 48 discovered  ·  %d coins  ·  %d free packs"
		% [Profile.data.owned.size(), int(Profile.data.coins), int(Profile.data.packs)]
	)
	home.get_node("Packs").text = (
		"Open a pack  →  %s"
		% ("%d free" % int(Profile.data.packs) if int(Profile.data.packs) > 0 else "60 coins")
	)


func _choose_starter(index: int) -> void:
	if Profile.choose_starter(index):
		_render_home()
		$Safe/Layout/Header/Balance.text = (
			"%d COINS  ·  %d / 48" % [int(Profile.data.coins), Profile.data.owned.size()]
		)
	else:
		_toast(Profile.last_error)


func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _make_card(
	parent: Node, id: String, owned: int = -1, unit: Dictionary = {}, compact: bool = false
) -> CardView:
	var view: CardView = CARD_SCENE.instantiate()
	parent.add_child(view)
	view.configure(id, owned, unit, compact)
	return view


func _render_pack() -> void:
	var packs: Node = screen("Packs")
	var pending: bool = not Profile.data.pending_pack.is_empty()
	var index: int = int(Profile.data.reveal_index)
	packs.get_node("Balance").text = (
		"%d free packs  ·  %d coins" % [int(Profile.data.packs), int(Profile.data.coins)]
	)
	packs.get_node("Open").visible = not pending
	packs.get_node("Next").visible = pending and index < 5
	packs.get_node("Skip").visible = pending and index < 5
	packs.get_node("Done").visible = pending and index == 5
	packs.get_node("Counter").text = (
		"%d / 5 revealed • Tap a card to inspect" % index
		if pending
		else "A new guardian is waiting to be discovered."
	)
	_clear(packs.get_node("Reveal"))
	if pending and index > 0:
		var id: String = Profile.data.pending_pack[index - 1]
		var view: CardView = _make_card(
			packs.get_node("Reveal"), id, int(Profile.data.owned.get(id, 0))
		)
		view.custom_minimum_size = Vector2(440, 540)
		view.selected.connect(_inspect.bind(id))
		if Profile.data.settings.animations:
			view.modulate.a = 0.0
			reveal_tween = create_tween()
			reveal_tween.tween_property(view, "modulate:a", 1.0, 0.3)
	elif not pending:
		var view: CardView = _make_card(packs.get_node("Reveal"), "aurelion")
		view.custom_minimum_size = Vector2(440, 540)
		view.selected.connect(_inspect.bind("aurelion"))


func _open_pack() -> void:
	if Profile.open_pack():
		_reveal_next()
	else:
		_toast(Profile.last_error)


func _reveal_next() -> void:
	if Profile.reveal_next():
		Audio.play_cue("reveal")
		_render_pack()
	else:
		_toast(Profile.last_error)


func _skip_reveal() -> void:
	if reveal_tween != null:
		reveal_tween.kill()
	var before: Dictionary = Profile.data.duplicate(true)
	Profile.data.reveal_index = 5
	if Profile.save():
		_render_pack()
	else:
		Profile.data = before
		_toast(Profile.last_error)


func _finish_pack() -> void:
	if Profile.finish_pack():
		show_screen("Collection")
	else:
		_toast(Profile.last_error)


func _render_collection() -> void:
	var collection: Node = screen("Collection")
	collection.get_node("Count").text = (
		"%d / 48 discovered • FIRST LIGHT" % Profile.data.owned.size()
	)
	_clear(collection.get_node("Grid"))
	var element_index: int = collection.get_node("Filters/Element").selected
	var rarity_index: int = collection.get_node("Filters/Rarity").selected
	var ownership: int = collection.get_node("Filters/Ownership").selected
	var search: String = collection.get_node("Search").text.to_lower()
	for id: String in Catalog.ordered_ids:
		var card: CardDefinition = Catalog.card(id)
		var owned: int = int(Profile.data.owned.get(id, 0))
		if (
			element_index > 0
			and card.element != collection.get_node("Filters/Element").get_item_text(element_index)
		):
			continue
		if (
			rarity_index > 0
			and card.rarity != collection.get_node("Filters/Rarity").get_item_text(rarity_index)
		):
			continue
		if (ownership == 1 and owned == 0) or (ownership == 2 and owned > 0):
			continue
		if not search.is_empty() and not card.display_name.to_lower().contains(search):
			continue
		var view: CardView = _make_card(collection.get_node("Grid"), id, owned)
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.selected.connect(_inspect.bind(id))


func _inspect(id: String) -> void:
	if current_screen == "Battle":
		_inspect_battle_card(id)
		return
	previous_screen = current_screen
	_clear(screen("Detail").get_node("Card"))
	var view: CardView = _make_card(
		screen("Detail").get_node("Card"), id, int(Profile.data.owned.get(id, 0))
	)
	view.custom_minimum_size = Vector2(520, 640)
	var card: CardDefinition = Catalog.card(id)
	var description: String = card.rules_text
	if card.is_creature():
		description = (
			"%s • %d HP • Retreat %d energy\n" % [card.element, card.max_hp, card.retreat_cost]
		)
		for attack: AttackDefinition in card.attacks:
			description += (
				"\n%s — %d energy, %d damage"
				% [attack.display_name, attack.energy_cost, attack.damage]
			)
			if attack.effect != null and attack.effect.amount > 0:
				description += " • %s %d" % [attack.effect.kind.capitalize(), attack.effect.amount]
	screen("Detail").get_node("Description").text = description
	screen("Detail").get_node("Lore").text = card.lore
	show_screen("Detail")


func _load_draft(index: int) -> void:
	if index < 0 or index >= Profile.data.decks.size():
		_new_deck()
		return
	draft_index = index
	draft = Profile.data.decks[index].cards.duplicate()
	screen("Decks").get_node("Name").text = Profile.data.decks[index].name
	_render_deck()


func _new_deck() -> void:
	draft_index = Profile.data.decks.size()
	draft = []
	screen("Decks").get_node("Name").text = "New guardians"
	_render_deck()


func _render_deck() -> void:
	var decks: Node = screen("Decks")
	var selector: OptionButton = decks.get_node("Selector")
	selector.clear()
	for deck: Dictionary in Profile.data.decks:
		selector.add_item(deck.name)
	if draft_index == Profile.data.decks.size():
		selector.add_item("New deck (unsaved)")
	selector.select(draft_index)
	var validation: String = Catalog.validate_deck(draft, Profile.data.owned)
	decks.get_node("Validation").text = (
		"✓ Valid deck • 20 / 20" if validation.is_empty() else validation
	)
	_clear(decks.get_node("Rows"))
	for id: String in Catalog.ordered_ids:
		var owned: int = int(Profile.data.owned.get(id, 0))
		if owned == 0:
			continue
		var row: HBoxContainer = ROW_SCENE.instantiate()
		decks.get_node("Rows").add_child(row)
		var count: int = draft.count(id)
		row.get_node("Card").text = "%s  %d/%d" % [Catalog.card(id).display_name, count, owned]
		row.get_node("Card").pressed.connect(_inspect.bind(id))
		row.get_node("Remove").disabled = count == 0
		row.get_node("Add").disabled = count >= mini(2, owned) or draft.size() >= 20
		row.get_node("Remove").pressed.connect(_change_deck.bind(id, -1))
		row.get_node("Add").pressed.connect(_change_deck.bind(id, 1))


func _change_deck(id: String, delta: int) -> void:
	if delta > 0:
		draft.append(id)
	else:
		draft.erase(id)
	_render_deck()


func _save_deck() -> void:
	var validation: String = Catalog.validate_deck(draft, Profile.data.owned)
	if not validation.is_empty():
		_toast(validation)
		return
	var before: Dictionary = Profile.data.duplicate(true)
	var deck_name: String = screen("Decks").get_node("Name").text.strip_edges().left(32)
	var deck: Dictionary = {
		"name": deck_name if not deck_name.is_empty() else "My guardians",
		"cards": draft.duplicate()
	}
	if draft_index == Profile.data.decks.size():
		Profile.data.decks.append(deck)
	else:
		Profile.data.decks[draft_index] = deck
	Profile.data.selected_deck = draft_index
	if not Profile.save():
		Profile.data = before
		_toast(Profile.last_error)
	else:
		_toast("Deck saved.")
		_render_deck()


func _render_setup() -> void:
	var selector: OptionButton = screen("Setup").get_node("Deck")
	selector.clear()
	for deck: Dictionary in Profile.data.decks:
		selector.add_item(deck.name)
	if selector.item_count > 0:
		selector.select(mini(int(Profile.data.selected_deck), selector.item_count - 1))


func _start_battle() -> void:
	if not Profile.data.battle.is_empty() and int(Profile.data.battle.winner) == -2:
		_modal(
			"Battle in progress",
			"Resume your current battle or concede it before starting another.",
			_resume_battle,
			false
		)
		return
	var setup: Node = screen("Setup")
	var index: int = setup.get_node("Deck").selected
	if index < 0:
		_toast("Save a valid deck first.")
		return
	var deck: Array = Profile.data.decks[index].cards
	var validation: String = Catalog.validate_deck(deck, Profile.data.owned)
	if not validation.is_empty():
		_toast(validation)
		return
	Profile.data.selected_deck = index
	var difficulty: int = setup.get_node("Difficulty").selected
	var enemy: Array = Array(Catalog.recipes[Profile.rng.randi_range(0, 2)].card_ids)
	rules.create(deck, enemy, difficulty, Profile.rng.randi())
	if not _persist_battle():
		return
	show_screen("Battle")
	if not Profile.data.tutorial:
		$AITimer.stop()
		_modal(
			"Welcome to the arena",
			"Tap your active, bench, or hand cards to open their overview and choose a legal action.\n\nYou can also use the fixed action panel below your hand. Inspect shows full card rules; History shows past moves. Attacking ends your turn. Reach three points or leave your rival without a replacement to win.\n\nThe starting player skips their first energy, draw and attack.",
			_finish_tutorial,
			false
		)


func _finish_tutorial() -> void:
	Profile.data.tutorial = true
	if not Profile.save():
		_toast(Profile.last_error)
	_render_battle()


func _resume_battle() -> void:
	rules.state = Profile.data.battle.duplicate(true)
	show_screen("Results" if int(rules.state.winner) != -2 else "Battle")


func _render_battle() -> void:
	if rules.state.is_empty():
		show_screen("Setup")
		return
	if int(rules.state.winner) != -2:
		if Profile.settle_match(rules.state):
			show_screen("Results")
		else:
			_toast(Profile.last_error)
		return
	var battle: Node = screen("Battle")
	var player: Dictionary = rules.state.players[0]
	var enemy: Dictionary = rules.state.players[1]
	var your_turn: bool = rules.current_actor() == 0
	battle.get_node("Status").text = (
		(
			"CHOOSE YOUR REPLACEMENT"
			if int(rules.state.replacement) == 0
			else ("YOUR TURN" if your_turn else "RIVAL IS THINKING…")
		)
		+ "  /  %d" % int(rules.state.turn_count)
	)
	battle.get_node("Score").text = (
		"YOU %d    ·    RIVAL %d    /    FIRST TO 3" % [int(player.points), int(enemy.points)]
	)
	battle.get_node("EnemyInfo").text = (
		"Rival • %d cards in hand • %d in deck" % [enemy.hand.size(), enemy.deck.size()]
	)
	for index: int in range(2):
		var parent: Node = battle.get_node(
			"Actives/" + ("YourActive" if index == 0 else "EnemyActive") + "/Card"
		)
		_clear(parent)
		var unit: Dictionary = rules.state.players[index].active
		if not unit.is_empty():
			var view: CardView = _make_battle_card(parent, unit.id, unit)
			view.custom_minimum_size = Vector2(0, 190)
			view.size_flags_vertical = Control.SIZE_EXPAND_FILL
			if index == 0:
				view.selected.connect(_open_unit_overview.bind(-1))
			else:
				view.selected.connect(_inspect_enemy_unit.bind(-1))
	_render_bench(0, battle.get_node("YourBench"))
	_render_bench(1, battle.get_node("EnemyBench"))
	battle.get_node("Resources").text = (
		"%d cards left  ·  Energy %s  ·  Support %s"
		% [
			player.deck.size(),
			"ready" if rules.state.energy_ready and your_turn else "spent",
			"used" if rules.state.support_used else "ready"
		]
	)
	_clear(battle.get_node("HandScroll/Hand"))
	for i: int in range(player.hand.size()):
		var view: CardView = _make_battle_card(battle.get_node("HandScroll/Hand"), player.hand[i])
		view.selected.connect(_open_hand_overview.bind(i))
	battle.get_node("Bottom/End").disabled = not your_turn or int(rules.state.replacement) >= 0
	battle.get_node("Bottom/Concede").disabled = not your_turn or int(rules.state.replacement) >= 0
	_render_actions()
	if not your_turn and not $Modal.visible and not $BattleOverlay.visible:
		$AITimer.start()


func _render_bench(index: int, parent: Node) -> void:
	_clear(parent)
	var bench: Array = rules.state.players[index].bench
	for i: int in range(3):
		var slot: Button = SLOT_SCENE.instantiate()
		parent.add_child(slot)
		slot.add_theme_font_size_override("font_size", 18)
		if i < bench.size():
			var unit: Dictionary = bench[i]
			slot.text = (
				"%s\n%d HP · %d E"
				% [Catalog.card(unit.id).display_name, int(unit.hp), int(unit.energy)]
			)
			if index == 0:
				slot.pressed.connect(_open_unit_overview.bind(i))
			else:
				slot.pressed.connect(_inspect_enemy_unit.bind(i))
		else:
			slot.text = "Empty bench"
			slot.disabled = true


func _select_unit(target: int) -> void:
	selected_target = target
	selected_mode = "unit"
	selected_hand = -1
	_render_actions()


func _select_hand(index: int) -> void:
	selected_hand = index
	selected_mode = "hand"
	_render_actions()


func _render_actions() -> void:
	var battle: Node = screen("Battle")
	var player: Dictionary = rules.state.players[0]
	var contextual: Array[Dictionary] = []
	var attacks: Array[Dictionary] = []
	var prompt: String = "Choose a creature or hand card."
	if selected_target >= player.bench.size():
		selected_target = -1
	if int(rules.state.replacement) == 0:
		prompt = "Choose a replacement."
	elif selected_mode == "hand" and selected_hand >= 0 and selected_hand < player.hand.size():
		prompt = Catalog.card(player.hand[selected_hand]).display_name
	else:
		var unit: Dictionary = rules.get_unit(0, selected_target)
		if not unit.is_empty():
			prompt = Catalog.card(unit.id).display_name + " · choose an action"
	for action: Dictionary in rules.legal_actions(0):
		var label: String = ""
		match action.type:
			"attack":
				var attack: AttackDefinition = Catalog.card(player.active.id).attacks[int(
					action.attack
				)]
				attacks.append(
					{
						"text":
						(
							"%s\n%d E · %d damage"
							% [
								attack.display_name,
								attack.energy_cost,
								rules.damage_for(0, int(action.attack))
							]
						),
						"action": action
					}
				)
			"promote":
				label = "Promote " + Catalog.card(player.bench[int(action.target)].id).display_name
			"attach":
				if selected_mode == "unit" and int(action.target) == selected_target:
					label = "Attach energy"
			"retreat":
				if selected_mode == "unit" and selected_target == int(action.target):
					label = "Retreat here · %d E" % Catalog.card(player.active.id).retreat_cost
			"deploy":
				if selected_mode == "hand" and selected_hand == int(action.hand):
					label = "Deploy to bench"
			"support":
				if selected_mode == "hand" and selected_hand == int(action.hand):
					var target: Dictionary = rules.get_unit(0, int(action.target))
					var card: CardDefinition = Catalog.card(player.hand[selected_hand])
					var verb: String = (
						"Move from " if card.effect.kind == "MOVE_ENERGY" else "Use on "
					)
					label = verb + Catalog.card(target.id).display_name
		if not label.is_empty():
			contextual.append({"text": label, "action": action})
	_configure_action_slots(battle.get_node("Actions"), contextual)
	_configure_action_slots(battle.get_node("Attacks"), attacks)
	battle.get_node("Selection/Prompt").text = prompt
	battle.get_node("Selection/Prompt").tooltip_text = prompt


func _configure_action_slots(
	parent: Node, actions: Array[Dictionary], overview: bool = false
) -> void:
	# Authored slots reserve a constant height, even when no action is legal.
	for index: int in range(parent.get_child_count()):
		var button: Button = parent.get_child(index)
		for connection: Dictionary in button.pressed.get_connections():
			button.pressed.disconnect(connection.callable)
		button.disabled = index >= actions.size()
		button.text = "—" if button.disabled else str(actions[index].text)
		button.tooltip_text = button.text
		if not button.disabled:
			var callback: Callable = _perform_overview_action if overview else _perform
			button.pressed.connect(callback.bind(actions[index].action))


func _make_battle_card(parent: Node, id: String, unit: Dictionary = {}) -> CardView:
	var view: CardView = BATTLE_CARD_SCENE.instantiate()
	parent.add_child(view)
	view.configure(id, -1, unit)
	view.get_node("Content/Footer").text = (
		(
			"%s · %d E · RETREAT %d"
			% [Catalog.card(id).element.to_upper(), int(unit.energy), Catalog.card(id).retreat_cost]
		)
		if not unit.is_empty()
		else Catalog.card(id).element.to_upper()
	)
	return view


func _open_unit_overview(target: int) -> void:
	_select_unit(target)
	_inspect_selection()


func _open_hand_overview(index: int) -> void:
	_select_hand(index)
	_inspect_selection()


func _inspect_enemy_unit(target: int) -> void:
	var unit: Dictionary = rules.get_unit(1, target)
	if not unit.is_empty():
		_inspect_battle_card(unit.id, unit)


func _inspect_selection() -> void:
	var player: Dictionary = rules.state.players[0]
	if selected_mode == "hand" and selected_hand >= 0 and selected_hand < player.hand.size():
		_inspect_battle_card(player.hand[selected_hand], {}, true)
	else:
		var unit: Dictionary = rules.get_unit(0, selected_target)
		if not unit.is_empty():
			_inspect_battle_card(unit.id, unit, true)


func _inspect_battle_card(id: String, unit: Dictionary = {}, own_card: bool = false) -> void:
	var card: CardDefinition = Catalog.card(id)
	$AITimer.stop()
	$BattleOverlay/Content/Title.text = card.display_name
	$BattleOverlay/Content/Art.visible = true
	$BattleOverlay/Content/Art.texture = load(card.art_path)
	var description: String = "%s · %s\n" % [card.element, card.rarity]
	if card.is_creature():
		if unit.is_empty():
			description += "%d HP · Retreat %d energy\n" % [card.max_hp, card.retreat_cost]
		else:
			description += (
				"%d / %d HP · %d energy · Retreat %d\nDamage boost: +%d this turn\n"
				% [
					int(unit.hp),
					card.max_hp,
					int(unit.energy),
					card.retreat_cost,
					int(unit.get("boost", 0))
				]
			)
		for attack: AttackDefinition in card.attacks:
			description += (
				"\n%s\n%d energy · %d damage"
				% [attack.display_name, attack.energy_cost, attack.damage]
			)
			if attack.effect != null and attack.effect.amount > 0:
				description += " · %s %d" % [attack.effect.kind.capitalize(), attack.effect.amount]
	else:
		description += card.rules_text
	$BattleOverlay/Content/Text.text = description + "\n\n" + card.lore
	$BattleOverlay/Content/Pages.hide()
	$BattleOverlay/Content/Error.hide()
	_render_overview_actions(own_card)
	$ModalBlocker.show()
	$BattleOverlay.show()


func _overview_actions() -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var player: Dictionary = rules.state.players[0]
	for action: Dictionary in rules.legal_actions(0):
		var label: String = ""
		if selected_mode == "hand":
			if int(action.get("hand", -1)) != selected_hand:
				continue
			if action.type == "deploy":
				label = "Deploy to bench"
			elif action.type == "support":
				var card: CardDefinition = Catalog.card(player.hand[selected_hand])
				var target: Dictionary = rules.get_unit(0, int(action.target))
				label = (
					("Move from " if card.effect.kind == "MOVE_ENERGY" else "Use on ")
					+ Catalog.card(target.id).display_name
				)
		else:
			match action.type:
				"attach":
					if int(action.target) == selected_target:
						label = "Attach energy"
				"retreat":
					if int(action.target) == selected_target:
						label = "Retreat here · %d E" % Catalog.card(player.active.id).retreat_cost
				"promote":
					if int(action.target) == selected_target:
						label = "Promote to active"
				"attack":
					if selected_target == -1:
						var attack: AttackDefinition = Catalog.card(player.active.id).attacks[int(
							action.attack
						)]
						label = (
							"%s\n%d E · %d damage"
							% [
								attack.display_name,
								attack.energy_cost,
								rules.damage_for(0, int(action.attack))
							]
						)
		if not label.is_empty():
			actions.append({"text": label, "action": action})
	return actions


func _render_overview_actions(own_card: bool) -> void:
	var actions: Array[Dictionary] = []
	if own_card:
		actions = _overview_actions()
	var grid: GridContainer = $BattleOverlay/Content/Actions
	_configure_action_slots(grid, actions, true)
	for index: int in range(grid.get_child_count()):
		grid.get_child(index).visible = index < actions.size()
	grid.visible = not actions.is_empty()
	$BattleOverlay/Content/Art.custom_minimum_size.y = 180 if grid.visible else 220


func _perform_overview_action(action: Dictionary) -> void:
	if not _apply_battle_action(0, action):
		# The rules may have changed since the window opened; refresh legal choices.
		_render_overview_actions(true)


func _show_history() -> void:
	history_page = maxi(0, (rules.state.log.size() - 1) / HISTORY_PAGE_SIZE)
	_render_history()


func _change_history_page(direction: int) -> void:
	history_page += direction
	_render_history()


func _render_history() -> void:
	$AITimer.stop()
	var page_count: int = maxi(1, ceili(float(rules.state.log.size()) / HISTORY_PAGE_SIZE))
	history_page = clampi(history_page, 0, page_count - 1)
	$BattleOverlay/Content/Title.text = "Battle history · %d / %d" % [history_page + 1, page_count]
	$BattleOverlay/Content/Art.hide()
	$BattleOverlay/Content/Actions.hide()
	$BattleOverlay/Content/Error.hide()
	$BattleOverlay/Content/Text.text = "\n\n".join(
		rules.state.log.slice(
			history_page * HISTORY_PAGE_SIZE, (history_page + 1) * HISTORY_PAGE_SIZE
		)
	)
	$BattleOverlay/Content/Pages.show()
	$BattleOverlay/Content/Pages/Previous.disabled = history_page == 0
	$BattleOverlay/Content/Pages/Next.disabled = history_page == page_count - 1
	$ModalBlocker.show()
	$BattleOverlay.show()


func _close_battle_overlay() -> void:
	$BattleOverlay.hide()
	$ModalBlocker.hide()
	if current_screen == "Battle":
		_render_battle()


func _perform(action: Dictionary) -> void:
	_apply_battle_action(0, action)


func _apply_battle_action(player_index: int, action: Dictionary) -> bool:
	var before: Dictionary = rules.state.duplicate(true)
	if not rules.apply_action(player_index, action):
		_toast("That action is no longer available.")
		return false
	if not _persist_battle():
		rules.state = before
		return false
	$BattleOverlay.hide()
	$ModalBlocker.hide()
	Audio.play_cue("attack" if action.type == "attack" else "tap")
	selected_hand = -1
	selected_mode = "unit"
	_render_battle()

	return true


func _persist_battle() -> bool:
	var before: Dictionary = Profile.data.battle.duplicate(true)
	Profile.data.battle = rules.state.duplicate(true)
	if not Profile.save():
		Profile.data.battle = before
		_toast(Profile.last_error)
		return false
	return true


func _ai_step() -> void:
	if (
		current_screen != "Battle"
		or $Modal.visible
		or $BattleOverlay.visible
		or rules.current_actor() != 1
		or int(rules.state.winner) != -2
	):
		return
	var action: Dictionary = BattleAI.choose(rules, 1, int(rules.state.difficulty))
	if not action.is_empty():
		_apply_battle_action(1, action)


func _ask_concede() -> void:
	_modal(
		"Concede this battle?",
		"Your rival will win. Conceding awards no coins.",
		_perform.bind({"type": "concede"})
	)


func _render_results() -> void:
	var battle: Dictionary = Profile.data.battle
	if battle.is_empty():
		show_screen("Home")
		return
	if not Profile.settle_match(battle):
		_toast(Profile.last_error)
	var results: Node = screen("Results")
	results.get_node("Title").text = (
		"Victory blooms."
		if int(battle.winner) == 0
		else ("A worthy rival." if int(battle.winner) == 1 else "An even match.")
	)
	results.get_node("Reason").text = battle.reason
	var reward: int = (
		(30 if int(battle.winner) == 0 else 10)
		if int(battle.winner) >= 0 and not battle.conceded
		else 0
	)
	results.get_node("Reward").text = "+%d coins" % reward


func _setting_changed(enabled: bool, key: String) -> void:
	var previous: bool = Profile.data.settings[key]
	Profile.data.settings[key] = enabled
	if not Profile.save():
		Profile.data.settings[key] = previous
		_toast(Profile.last_error)
	Audio.apply_settings()


func _modal(title: String, text: String, callback: Callable, cancel: bool = true) -> void:
	$AITimer.stop()
	modal_callback = callback
	$Modal/Content/Title.text = title
	$Modal/Content/Text.text = text
	$Modal/Content/Buttons/Cancel.visible = cancel
	$Modal/Content/Buttons/OK.text = "Confirm" if cancel else "Continue"
	$ModalBlocker.show()
	$Modal.show()


func _confirm_modal() -> void:
	$Modal.hide()
	$ModalBlocker.hide()
	if modal_callback.is_valid():
		modal_callback.call()


func _dismiss_modal() -> void:
	$Modal.hide()
	$ModalBlocker.hide()
	if current_screen == "Battle":
		_render_battle()


func _toast(message: String) -> void:
	if $BattleOverlay.visible:
		$BattleOverlay/Content/Error.text = message
		$BattleOverlay/Content/Error.visible = not message.is_empty()
		$Safe/Layout/Toast.hide()
		return
	$Safe/Layout/Toast.text = message
	$Safe/Layout/Toast.visible = not message.is_empty()


func _update_safe_area() -> void:
	if OS.get_name() != "Android":
		return
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var window: Vector2i = DisplayServer.window_get_size()
	var scale_y: float = size.y / maxf(window.y, 1)
	$Safe.add_theme_constant_override("margin_top", 18 + int(safe.position.y * scale_y))
	$Safe.add_theme_constant_override(
		"margin_bottom", 14 + int(maxi(0, window.y - safe.end.y) * scale_y)
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Some Android devices dispatch one Back gesture twice within milliseconds.
		# Consume it once so dismissing an overlay cannot also leave its screen.
		var now: int = Time.get_ticks_msec()
		if now - _last_back_request_ms < BACK_REQUEST_INTERVAL_MS:
			return
		_last_back_request_ms = now
		if $BattleOverlay.visible:
			_close_battle_overlay()
		elif $Modal.visible:
			_dismiss_modal()
		elif current_screen == "Detail":
			show_screen(previous_screen)
		else:
			show_screen("Home")
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		$AITimer.stop()
		Profile.save()
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			Audio.shutdown()
			await get_tree().create_timer(0.15).timeout
			get_tree().quit()

	elif what == NOTIFICATION_APPLICATION_RESUMED and is_node_ready():
		if current_screen == "Battle" and not $BattleOverlay.visible and not $Modal.visible:
			_render_battle()
