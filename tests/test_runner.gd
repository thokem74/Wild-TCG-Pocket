extends Node

var checks: int = 0
var failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	await get_tree().process_frame
	_test_catalog()
	_test_openings()
	_test_actions()
	_test_effects()
	_test_endings()
	_test_persistence()
	_test_ai()
	print("TEST RESULTS: %d checks, %d failures" % [checks, failures])
	Audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1 if failures > 0 else 0)


func deck(index: int = 0) -> Array:
	return Array(Catalog.recipes[index].card_ids)


func battle(seed_value: int = 42) -> BattleRules:
	var result: BattleRules = BattleRules.new()
	result.create(deck(), deck(1), 2, seed_value)
	return result


func prepare(rules: BattleRules) -> void:
	rules.state.turn = 0
	rules.state.turn_count = 3
	rules.state.energy_ready = true
	rules.state.players[0].active = unit("emberlyn", 70, 4)
	rules.state.players[1].active = unit("pearlfin", 70, 1)
	rules.state.players[0].bench = [unit("cinderhorn", 80, 2)]
	rules.state.players[1].bench = [unit("mistwhale", 80, 1)]


func unit(id: String, hp: int, energy: int) -> Dictionary:
	return {"id": id, "hp": hp, "energy": energy, "boost": 0}


func _test_catalog() -> void:
	check(Catalog.cards.size() == 48, "48 card catalog")
	var rarities: Dictionary = {"Common": 0, "Uncommon": 0, "Rare": 0, "Legendary": 0}
	for id: String in Catalog.ordered_ids:
		rarities[Catalog.card(id).rarity] += 1
	check(
		rarities == {"Common": 24, "Uncommon": 12, "Rare": 9, "Legendary": 3}, "rarity distribution"
	)
	for i: int in range(3):
		check(Catalog.validate_deck(deck(i)).is_empty(), "valid starter %d" % i)
	check(not Catalog.validate_deck([]).is_empty(), "reject empty deck")
	var invalid: Array = deck()
	invalid[2] = invalid[0]
	check(not Catalog.validate_deck(invalid).is_empty(), "reject third copy")
	var support_only: Array = []
	for id: String in Catalog.ordered_ids:
		if not Catalog.card(id).is_creature() and support_only.size() < 20:
			support_only.append(id)
			support_only.append(id)
	check(not Catalog.validate_deck(support_only).is_empty(), "reject no creatures")
	check(not Catalog.validate_deck(deck(), {"emberlyn": 1}).is_empty(), "reject unowned copies")


func _test_openings() -> void:
	for seed_value: int in range(100):
		var rules: BattleRules = battle(seed_value)
		check(not rules.state.energy_ready, "starting energy skipped")
		for player: Dictionary in rules.state.players:
			check(Catalog.card(player.active.id).is_creature(), "guaranteed creature")
			check(
				player.hand.size() == 4 and player.deck.size() == 15,
				"five-card opening including active"
			)
		for action: Dictionary in rules.legal_actions(rules.current_actor()):
			check(action.type != "attack" and action.type != "attach", "starting restrictions")
		var initial_actor: int = rules.current_actor()
		check(rules.apply_action(initial_actor, {"type": "end"}), "first turn can end")
		check(
			rules.state.energy_ready and rules.state.players[1 - initial_actor].deck.size() == 14,
			"second turn draw and energy"
		)


func _test_actions() -> void:
	var rules: BattleRules = battle()
	prepare(rules)
	check(not rules.apply_action(1, {"type": "end"}), "opponent cannot act")
	check(not rules.apply_action(0, {"type": "attach", "target": 88}), "invalid target rejected")
	check(rules.apply_action(0, {"type": "attach", "target": 0}), "attach to bench")
	check(not rules.apply_action(0, {"type": "attach", "target": -1}), "only one energy")
	check(rules.apply_action(0, {"type": "retreat", "target": 0}), "retreat legal")
	check(int(rules.state.players[0].bench[0].energy) == 3, "retreat discards exact cost")
	check(not rules.apply_action(0, {"type": "retreat", "target": 0}), "once per turn retreat")
	rules.state.players[0].active.energy = 0
	check(not rules.apply_action(0, {"type": "attack", "attack": 0}), "attack requires energy")
	rules.state.players[0].hand = ["solwing", "suncub", "coalwyrm"]
	check(rules.apply_action(0, {"type": "deploy", "hand": 0}), "deploy creature")
	check(rules.apply_action(0, {"type": "deploy", "hand": 0}), "third bench creature")
	check(not rules.apply_action(0, {"type": "deploy", "hand": 0}), "three bench limit")


func _test_effects() -> void:
	var rules: BattleRules = battle()
	prepare(rules)
	rules.state.players[0].active.hp = 20
	rules.state.players[0].hand = ["dew_vial", "moon_nectar"]
	check(rules.apply_action(0, {"type": "support", "hand": 0, "target": -1}), "heal support")
	check(int(rules.state.players[0].active.hp) == 40, "healing exact")
	check(
		not rules.apply_action(0, {"type": "support", "hand": 0, "target": -1}),
		"one support per turn"
	)
	rules.state.support_used = false
	rules.state.players[0].hand = ["current_relay"]
	check(rules.apply_action(0, {"type": "support", "hand": 0, "target": 0}), "move energy support")
	check(
		(
			int(rules.state.players[0].active.energy) == 5
			and int(rules.state.players[0].bench[0].energy) == 1
		),
		"energy conserved"
	)
	rules.state.support_used = false
	rules.state.players[0].hand = ["warcry_sigil"]
	check(rules.apply_action(0, {"type": "support", "hand": 0, "target": -1}), "boost support")
	check(rules.damage_for(0, 0) == 40, "boost adds damage")
	check(rules.apply_action(0, {"type": "end"}), "end boosted turn")
	check(int(rules.state.players[0].active.boost) == 0, "boost expires")
	prepare(rules)
	rules.state.players[1].active = unit("zephyrkit", 70, 1)
	check(rules.damage_for(0, 0) == 40, "elemental weakness")
	rules.state.players[0].active.hp = 40
	var before_energy: int = int(rules.state.players[0].active.energy)
	check(rules.apply_action(0, {"type": "attack", "attack": 0}), "attack works")
	check(int(rules.state.players[0].active.energy) == before_energy, "attacks retain energy")
	check(int(rules.state.turn) == 1, "attack ends turn")
	check(int(rules.state.players[0].active.hp) == 50, "attack healing effect")
	prepare(rules)
	rules.state.players[0].hand = ["astral_compass"]
	rules.state.support_used = false
	var before_draw: int = rules.state.players[0].hand.size()
	check(rules.apply_action(0, {"type": "support", "hand": 0, "target": -1}), "draw support")
	check(
		rules.state.players[0].hand.size() == before_draw + 1,
		"support draws two after consuming itself"
	)


func _test_endings() -> void:
	var rules: BattleRules = battle()
	prepare(rules)
	rules.state.players[1].active.hp = 10
	check(rules.apply_action(0, {"type": "attack", "attack": 1}), "knockout attack")
	check(
		int(rules.state.players[0].points) == 1 and int(rules.state.replacement) == 1,
		"point and pending replacement"
	)
	check(rules.apply_action(1, {"type": "promote", "target": 0}), "promote replacement")
	check(int(rules.state.turn) == 1, "replacement begins defender turn")
	prepare(rules)
	rules.state.players[0].points = 2
	rules.state.players[1].active.hp = 10
	rules.apply_action(0, {"type": "attack", "attack": 1})
	check(int(rules.state.winner) == 0, "three points wins")
	rules = battle()
	prepare(rules)
	rules.state.players[1].bench = []
	rules.state.players[1].active.hp = 10
	rules.apply_action(0, {"type": "attack", "attack": 1})
	check(int(rules.state.winner) == 0, "no replacement loses")
	rules = battle()
	prepare(rules)
	rules.state.players[1].deck = []
	rules.apply_action(0, {"type": "end"})
	check(int(rules.state.winner) == 0, "unable to draw loses")
	rules = battle()
	prepare(rules)
	rules.state.turn_count = 60
	rules.apply_action(0, {"type": "end"})
	check(int(rules.state.winner) == -1, "60-turn draw")
	rules = battle()
	prepare(rules)
	rules.apply_action(0, {"type": "concede"})
	check(rules.state.conceded and int(rules.state.winner) == 1, "concede")


func _test_persistence() -> void:
	Profile.data = Profile.fresh_data()
	check(Profile.choose_starter(0), "starter saved")
	check(not Profile.choose_starter(1), "starter cannot repeat")
	check(Profile.open_pack(), "open pack")
	var pending: Array = Profile.data.pending_pack.duplicate()
	var packs_before: int = int(Profile.data.packs)
	check(
		(
			Profile.open_pack()
			and pending == Profile.data.pending_pack
			and packs_before == int(Profile.data.packs)
		),
		"pending pack idempotent"
	)
	for i: int in range(5):
		var rarity: String = Catalog.card(pending[i]).rarity
		check(
			rarity in (["Common", "Uncommon"] if i < 4 else ["Rare", "Legendary"]),
			"pack slot rarity"
		)
	check(Profile.reveal_next(), "reveal saved")
	var loaded: Dictionary = Profile._read_save(Profile.SAVE_PATH)
	check(
		loaded.pending_pack == pending and int(loaded.reveal_index) == 1,
		"interrupted reveal restored"
	)
	var rules: BattleRules = battle()
	prepare(rules)
	rules.apply_action(0, {"type": "attach", "target": -1})
	Profile.data.battle = rules.state.duplicate(true)
	Profile.save()
	loaded = Profile._read_save(Profile.SAVE_PATH)
	check(
		loaded.battle == JSON.parse_string(JSON.stringify(rules.state)), "battle restored exactly"
	)
	rules.state.winner = 0
	var coins: int = int(Profile.data.coins)
	check(Profile.settle_match(rules.state), "reward saved")
	check(
		Profile.settle_match(rules.state) and int(Profile.data.coins) == coins + 30,
		"reward only once"
	)
	rules.state.id = "conceded-test"
	rules.state.conceded = true
	Profile.settle_match(rules.state)
	check(int(Profile.data.coins) == coins + 30, "no concede reward")
	Profile.data.owned = {}
	for i: int in range(24):
		Profile.data.owned[Catalog.ordered_ids[i]] = 1
	Profile.data.milestones = []
	var before_packs: int = int(Profile.data.packs)
	Profile._check_milestones()
	Profile._check_milestones()
	check(int(Profile.data.packs) == before_packs + 2, "milestones exactly once")
	Profile.save()
	var file: FileAccess = FileAccess.open(Profile.SAVE_PATH, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(Profile._read_save(Profile.SAVE_PATH).is_empty(), "corrupt primary rejected")
	check(not Profile._read_save(Profile.BACKUP_PATH).is_empty(), "backup recovers")
	Profile.data = Profile.fresh_data()
	Profile.save()


func _test_ai() -> void:
	var winners: Array[int] = [0, 0, 0]
	var total_turns: int = 0
	for seed_value: int in range(180):
		var rules: BattleRules = BattleRules.new()
		rules.create(
			deck(seed_value % 3), deck((seed_value / 3) as int % 3), seed_value % 3, seed_value
		)
		var actions: int = 0
		while int(rules.state.winner) == -2 and actions < 600:
			var actor: int = rules.current_actor()
			var action: Dictionary = BattleAI.choose(rules, actor, seed_value % 3)
			check(not action.is_empty(), "AI has action")
			check(rules.apply_action(actor, action), "AI action legal")
			actions += 1
		check(int(rules.state.winner) != -2, "AI match completes")
		if int(rules.state.winner) >= 0:
			winners[int(rules.state.winner)] += 1
		else:
			winners[2] += 1
		total_turns += int(rules.state.turn_count)
	print("AI simulation: wins %s, average turns %.1f" % [winners, total_turns / 180.0])
