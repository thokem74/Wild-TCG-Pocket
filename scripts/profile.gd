extends Node

signal changed

const SAVE_PATH: String = "user://progress.json"
const BACKUP_PATH: String = "user://progress.backup.json"
var data: Dictionary = {}
var last_error: String = ""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	data = _read_save(SAVE_PATH)
	if data.is_empty():
		data = _read_save(BACKUP_PATH)
	if data.is_empty():
		data = fresh_data()


func fresh_data() -> Dictionary:
	return {
		"version": 1,
		"starter": -1,
		"owned": {},
		"decks": [],
		"selected_deck": 0,
		"coins": 0,
		"packs": 3,
		"milestones": [],
		"pending_pack": [],
		"reveal_index": 0,
		"battle": {},
		"rewarded_matches": [],
		"tutorial": false,
		"settings": {"music": true, "sfx": true, "animations": true, "battle_effects": true}
	}


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary or int(parsed.get("version", 0)) != 1:
		return {}
	# Validate the entire shape before allowing saved data into the UI or rules engine.
	var defaults: Dictionary = fresh_data()
	for key: String in defaults:
		if not parsed.has(key) or typeof(parsed[key]) != typeof(defaults[key]):
			# JSON stores integers as floats.
			if not (defaults[key] is int and parsed.get(key) is float):
				return {}
	for id: String in parsed.owned:
		if not parsed.owned[id] is float and not parsed.owned[id] is int:
			return {}
		if not Catalog.cards.has(id) or int(parsed.owned[id]) <= 0:
			return {}
	for deck: Variant in parsed.decks:
		if (
			not deck is Dictionary
			or not deck.get("cards") is Array
			or not deck.get("name") is String
		):
			return {}
		for id: Variant in deck.cards:
			if not id is String or not Catalog.cards.has(id):
				return {}
	for id: Variant in parsed.pending_pack:
		if not id is String or not Catalog.cards.has(id):
			return {}

	if not BattleRules.valid_snapshot(parsed.battle):
		return {}
	if (
		int(parsed.starter) < -1
		or int(parsed.starter) > 2
		or int(parsed.coins) < 0
		or int(parsed.packs) < 0
	):
		return {}
	if (
		int(parsed.starter) >= 0
		and (
			parsed.decks.is_empty()
			or int(parsed.selected_deck) < 0
			or int(parsed.selected_deck) >= parsed.decks.size()
		)
	):
		return {}
	if int(parsed.reveal_index) < 0 or int(parsed.reveal_index) > parsed.pending_pack.size():
		return {}
	if parsed.pending_pack.size() not in [0, 5]:
		return {}
	# Older version-1 saves predate the independent battle effects setting.
	if not parsed.settings.has("battle_effects"):
		parsed.settings.battle_effects = true
	for key: String in ["music", "sfx", "animations", "battle_effects"]:
		if not parsed.settings.get(key) is bool:
			return {}
	return parsed


func save() -> bool:
	var temporary: String = SAVE_PATH + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Could not save progress. Free some device storage and try again."
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		# Do not replace a good backup with a damaged primary file.
		if not _read_save(SAVE_PATH).is_empty():
			DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	var result: Error = DirAccess.rename_absolute(temporary, SAVE_PATH)
	last_error = "" if result == OK else "Progress could not be saved. Please try again."
	if result == OK:
		changed.emit()
	return result == OK


func choose_starter(index: int) -> bool:
	if int(data.starter) >= 0 or index < 0 or index >= Catalog.recipes.size():
		return false
	var before: Dictionary = data.duplicate(true)
	var recipe: DeckRecipe = Catalog.recipes[index]
	data.starter = index
	for id: String in recipe.card_ids:
		data.owned[id] = int(data.owned.get(id, 0)) + 1
	data.decks = [{"name": recipe.display_name, "cards": Array(recipe.card_ids)}]
	_check_milestones()
	return _commit(before)


func _commit(before: Dictionary) -> bool:
	if save():
		return true
	data = before
	return false


func open_pack() -> bool:
	if not data.pending_pack.is_empty():
		return true
	if int(data.packs) <= 0 and int(data.coins) < 60:
		last_error = "Earn coins in quick battles. A pack costs 60 coins."
		return false
	var before: Dictionary = data.duplicate(true)
	if int(data.packs) > 0:
		data.packs -= 1
	else:
		data.coins -= 60
	var result: Array = []
	for slot: int in range(5):
		var roll: float = rng.randf()
		var rarity: String = (
			("Common" if roll < 0.8 else "Uncommon")
			if slot < 4
			else ("Rare" if roll < 0.9 else "Legendary")
		)
		var pool: Array[String] = []
		for id: String in Catalog.ordered_ids:
			if Catalog.card(id).rarity == rarity:
				pool.append(id)
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		result.append(id)
		data.owned[id] = int(data.owned.get(id, 0)) + 1
	# Contents, inventory and payment commit together before any reveal animation.
	data.pending_pack = result
	data.reveal_index = 0
	_check_milestones()
	return _commit(before)


func _check_milestones() -> void:
	for threshold: int in [12, 24, 36, 48]:
		if data.owned.size() >= threshold and not data.milestones.has(threshold):
			data.milestones.append(threshold)
			data.packs += 1


func reveal_next() -> bool:
	var before: Dictionary = data.duplicate(true)
	data.reveal_index = mini(int(data.reveal_index) + 1, data.pending_pack.size())
	return _commit(before)


func finish_pack() -> bool:
	var before: Dictionary = data.duplicate(true)
	data.pending_pack = []
	data.reveal_index = 0
	return _commit(before)


func settle_match(battle: Dictionary) -> bool:
	if int(battle.winner) == -2:
		return false
	var before: Dictionary = data.duplicate(true)
	if not data.rewarded_matches.has(battle.id):
		var reward: int = 0
		if not battle.conceded and int(battle.winner) >= 0:
			reward = 30 if int(battle.winner) == 0 else 10
		data.coins += reward
		data.rewarded_matches.append(battle.id)
	data.battle = battle.duplicate(true)
	return _commit(before)
