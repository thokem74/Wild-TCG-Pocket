class_name BattleAI
extends RefCounted


## Scores only legal actions and public board information; never inspects a deck.
static func choose(rules: BattleRules, player_index: int, difficulty: int) -> Dictionary:
	var actions: Array[Dictionary] = rules.legal_actions(player_index)
	var best: Dictionary = {}
	var best_score: float = -INF
	for action: Dictionary in actions:
		if action.type == "concede":
			continue
		var score: float = _score(rules, player_index, action, difficulty)
		if score > best_score:
			best_score = score
			best = action
	return best


static func _score(
	rules: BattleRules, player_index: int, action: Dictionary, difficulty: int
) -> float:
	var player: Dictionary = rules.state.players[player_index]
	match action.type:
		"promote":
			var unit: Dictionary = player.bench[int(action.target)]
			return float(unit.hp) + float(unit.energy) * (30.0 if difficulty > 0 else 0.0)
		"deploy":
			return 90.0 + Catalog.card(player.hand[int(action.hand)]).max_hp * 0.01
		"attach":
			if int(action.target) == -1:
				var attacks: Array[Resource] = Catalog.card(player.active.id).attacks
				if (
					difficulty < 2
					or int(player.active.energy) < attacks[-1].energy_cost
					or player.bench.is_empty()
				):
					return 80.0
				return 35.0
			return 60.0 if difficulty == 2 else 30.0
		"support":
			var card: CardDefinition = Catalog.card(player.hand[int(action.hand)])
			if card.effect.kind == "DRAW":
				return 75.0 if player.deck.size() > card.effect.amount + 2 else -20.0
			if card.effect.kind == "BOOST":
				return (
					72.0
					if (
						int(player.active.energy)
						>= Catalog.card(player.active.id).attacks[0].energy_cost
					)
					else -10.0
				)
			if card.effect.kind == "HEAL":
				var unit: Dictionary = rules.get_unit(player_index, int(action.target))
				return (
					70.0
					if Catalog.card(unit.id).max_hp - int(unit.hp) >= card.effect.amount / 2
					else 5.0
				)
			return 65.0
		"attack":
			var damage: int = rules.damage_for(player_index, int(action.attack))
			return 50.0 + (damage * 0.1 if difficulty > 0 else -float(action.attack))
		"retreat":
			if difficulty == 2:
				var unit: Dictionary = player.bench[int(action.target)]
				if (
					int(player.active.hp) <= 30
					and int(unit.energy) >= Catalog.card(unit.id).attacks[0].energy_cost
				):
					return 85.0
			return -5.0
	return 0.0
