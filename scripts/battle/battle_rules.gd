class_name BattleRules
extends RefCounted

## Serializable rules engine. Neither actions nor AI can bypass legal_actions().
signal changed

var state: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func create(player_deck: Array, enemy_deck: Array, difficulty: int, seed_value: int) -> void:
	rng.seed = seed_value
	state = {
		"id": "%d-%d" % [Time.get_unix_time_from_system(), seed_value],
		"players": [],
		"turn": rng.randi_range(0, 1),
		"turn_count": 1,
		"winner": -2,
		"reason": "",
		"conceded": false,
		"difficulty": difficulty,
		"energy_ready": false,
		"support_used": false,
		"retreat_used": false,
		"replacement": -1,
		"log": ["The guardians enter the arena."]
	}
	for deck: Array in [player_deck, enemy_deck]:
		var shuffled: Array = deck.duplicate()
		_shuffle(shuffled)
		# Swap a creature into the opening five instead of retrying indefinitely.
		var has_creature: bool = false
		for i: int in range(5):
			has_creature = has_creature or Catalog.card(shuffled[i]).is_creature()
		if not has_creature:
			for i: int in range(5, shuffled.size()):
				if Catalog.card(shuffled[i]).is_creature():
					var swap: String = shuffled[0]
					shuffled[0] = shuffled[i]
					shuffled[i] = swap
					break
		var hand: Array = []
		for i: int in range(5):
			hand.append(shuffled.pop_front())
		var active_id: String = ""
		for id: String in hand:
			if Catalog.card(id).is_creature():
				active_id = id
				break
		hand.erase(active_id)
		state.players.append(
			{
				"deck": shuffled,
				"hand": hand,
				"active": _unit(active_id),
				"bench": [],
				"discard": [],
				"points": 0
			}
		)
	changed.emit()


func _shuffle(items: Array) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap


func _unit(id: String) -> Dictionary:
	return {"id": id, "hp": Catalog.card(id).max_hp, "energy": 0, "boost": 0}


func current_actor() -> int:
	return int(state.replacement) if int(state.replacement) >= 0 else int(state.turn)


func legal_actions(player_index: int) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if state.is_empty() or int(state.winner) != -2 or player_index != current_actor():
		return actions
	var player: Dictionary = state.players[player_index]
	if int(state.replacement) >= 0:
		for i: int in range(player.bench.size()):
			actions.append({"type": "promote", "target": i})
		return actions
	for i: int in range(player.hand.size()):
		var card: CardDefinition = Catalog.card(player.hand[i])
		if card.is_creature():
			if player.bench.size() < 3:
				actions.append({"type": "deploy", "hand": i})
		elif not state.support_used:
			match card.effect.kind:
				"HEAL":
					for target: int in range(-1, player.bench.size()):
						var unit: Dictionary = get_unit(player_index, target)
						if int(unit.hp) < Catalog.card(unit.id).max_hp:
							actions.append({"type": "support", "hand": i, "target": target})
				"MOVE_ENERGY":
					for target: int in range(player.bench.size()):
						if int(player.bench[target].energy) >= card.effect.amount:
							actions.append({"type": "support", "hand": i, "target": target})
				_:
					actions.append({"type": "support", "hand": i, "target": -1})
	if state.energy_ready:
		for target: int in range(-1, player.bench.size()):
			actions.append({"type": "attach", "target": target})
	if (
		not state.retreat_used
		and int(player.active.energy) >= Catalog.card(player.active.id).retreat_cost
	):
		for target: int in range(player.bench.size()):
			actions.append({"type": "retreat", "target": target})
	if int(state.turn_count) > 1:
		var attacks: Array[Resource] = Catalog.card(player.active.id).attacks
		for i: int in range(attacks.size()):
			if int(player.active.energy) >= attacks[i].energy_cost:
				actions.append({"type": "attack", "attack": i})
	actions.append({"type": "end"})
	actions.append({"type": "concede"})
	return actions


func get_unit(player: int, target: int) -> Dictionary:
	return state.players[player].active if target == -1 else state.players[player].bench[target]


func apply_action(player_index: int, action: Dictionary) -> bool:
	if not legal_actions(player_index).has(action):
		return false
	var player: Dictionary = state.players[player_index]
	match action.type:
		"promote":
			player.active = player.bench.pop_at(int(action.target))
			state.replacement = -1
			_log("%s takes the active position." % Catalog.card(player.active.id).display_name)
			_begin_next_turn()
		"deploy":
			var id: String = player.hand.pop_at(int(action.hand))
			player.bench.append(_unit(id))
			_log("%s joins the bench." % Catalog.card(id).display_name)
		"attach":
			get_unit(player_index, int(action.target)).energy += 1
			state.energy_ready = false
			_log("An energy orb was attached.")
		"support":
			var id: String = player.hand.pop_at(int(action.hand))
			player.discard.append(id)
			state.support_used = true
			_apply_effect(player_index, Catalog.card(id).effect, int(action.target))
			_log("%s used %s." % [_player_name(player_index), Catalog.card(id).display_name])
		"retreat":
			player.active.energy -= Catalog.card(player.active.id).retreat_cost
			var previous: Dictionary = player.active
			player.active = player.bench[int(action.target)]
			player.bench[int(action.target)] = previous
			state.retreat_used = true
			_log("%s retreated." % Catalog.card(previous.id).display_name)
		"attack":
			_attack(player_index, int(action.attack))
		"end":
			_log("%s passed." % _player_name(player_index))
			_begin_next_turn()
		"concede":
			state.conceded = true
			_finish(1 - player_index, "Conceded")
	changed.emit()
	return true


func damage_for(player_index: int, attack_index: int, attacker: Dictionary = {}) -> int:
	var unit: Dictionary = state.players[player_index].active if attacker.is_empty() else attacker
	var card: CardDefinition = Catalog.card(unit.id)
	var defender: CardDefinition = Catalog.card(state.players[1 - player_index].active.id)
	var weakness: Dictionary = {"Flame": "Gale", "Gale": "Tide", "Tide": "Flame"}
	return (
		card.attacks[attack_index].damage
		+ int(unit.boost)
		+ (20 if weakness[card.element] == defender.element else 0)
	)


func _attack(player_index: int, attack_index: int) -> void:
	var player: Dictionary = state.players[player_index]
	var enemy: Dictionary = state.players[1 - player_index]
	var attack: AttackDefinition = Catalog.card(player.active.id).attacks[attack_index]
	var damage: int = damage_for(player_index, attack_index)
	enemy.active.hp -= damage
	_log(
		(
			"%s: %s deals %d damage!"
			% [Catalog.card(player.active.id).display_name, attack.display_name, damage]
		)
	)
	if int(enemy.active.hp) <= 0:
		player.points += 1
		enemy.discard.append(enemy.active.id)
		_log("Knockout! %s earns a point." % _player_name(player_index))
		if int(player.points) >= 3:
			_finish(player_index, "Three points")
		elif enemy.bench.is_empty():
			_finish(player_index, "No creatures left to replace the active guardian")
		else:
			enemy.active = {}
			state.replacement = 1 - player_index
	if int(state.winner) == -2 and attack.effect != null:
		_apply_effect(player_index, attack.effect, -1)
	if int(state.winner) == -2 and int(state.replacement) < 0:
		_begin_next_turn()


func _apply_effect(player_index: int, effect: EffectDefinition, target: int) -> void:
	var player: Dictionary = state.players[player_index]
	match effect.kind:
		"HEAL":
			var unit: Dictionary = get_unit(player_index, target)
			unit.hp = mini(int(unit.hp) + effect.amount, Catalog.card(unit.id).max_hp)
		"DRAW":
			for i: int in range(effect.amount):
				if not _draw(player_index):
					break
		"MOVE_ENERGY":
			player.bench[target].energy -= effect.amount
			player.active.energy += effect.amount
		"BOOST":
			player.active.boost += effect.amount


func _draw(player_index: int) -> bool:
	var player: Dictionary = state.players[player_index]
	if player.deck.is_empty():
		_finish(1 - player_index, "Unable to draw a card")
		return false
	player.hand.append(player.deck.pop_front())
	return true


func _begin_next_turn() -> void:
	for player: Dictionary in state.players:
		if not player.active.is_empty():
			player.active.boost = 0
		for unit: Dictionary in player.bench:
			unit.boost = 0
	if int(state.turn_count) >= 60:
		_finish(-1, "Turn limit reached")
		return
	state.turn = 1 - int(state.turn)
	state.turn_count += 1
	state.energy_ready = true
	state.support_used = false
	state.retreat_used = false
	_draw(int(state.turn))


func _finish(winner: int, reason: String) -> void:
	state.winner = winner
	state.reason = reason
	_log(reason)


func _player_name(index: int) -> String:
	return "You" if index == 0 else "Rival"


func _log(message: String) -> void:
	state.log.append(message)
	if state.log.size() > 40:
		state.log.pop_front()


static func valid_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return true
	for key: String in ["id", "reason"]:
		if not snapshot.get(key) is String:
			return false
	for key: String in ["conceded", "energy_ready", "support_used", "retreat_used"]:
		if not snapshot.get(key) is bool:
			return false
	for key: String in ["turn", "turn_count", "winner", "difficulty", "replacement"]:
		if not snapshot.get(key) is float and not snapshot.get(key) is int:
			return false
	if int(snapshot.turn) not in [0, 1] or int(snapshot.winner) not in [-2, -1, 0, 1]:
		return false
	if (
		int(snapshot.replacement) not in [-1, 0, 1]
		or int(snapshot.turn_count) < 1
		or int(snapshot.turn_count) > 60
	):
		return false
	if int(snapshot.difficulty) not in [0, 1, 2]:
		return false
	if not snapshot.get("players") is Array or snapshot.players.size() != 2:
		return false
	if not snapshot.get("log") is Array:
		return false
	for line: Variant in snapshot.log:
		if not line is String:
			return false
	for index: int in range(2):
		var player: Variant = snapshot.players[index]
		if not player is Dictionary:
			return false
		for key: String in ["hand", "deck", "discard"]:
			if not player.get(key) is Array:
				return false
			for id: Variant in player[key]:
				if not id is String or not Catalog.cards.has(id):
					return false
		if not player.get("points") is float and not player.get("points") is int:
			return false
		if int(player.points) < 0 or int(player.points) > 3:
			return false
		if (
			not player.get("active") is Dictionary
			or not player.get("bench") is Array
			or player.bench.size() > 3
		):
			return false
		if player.active.is_empty():
			if int(snapshot.replacement) != index:
				return false
		elif not _valid_unit(player.active):
			return false
		for unit: Variant in player.bench:
			if not unit is Dictionary or not _valid_unit(unit):
				return false
	return true


static func _valid_unit(unit: Dictionary) -> bool:
	if (
		not unit.get("id") is String
		or not Catalog.cards.has(unit.id)
		or not Catalog.card(unit.id).is_creature()
	):
		return false
	for key: String in ["hp", "energy", "boost"]:
		if not unit.get(key) is int and not unit.get(key) is float:
			return false
	return (
		int(unit.hp) <= Catalog.card(unit.id).max_hp
		and int(unit.energy) >= 0
		and int(unit.boost) >= 0
	)
