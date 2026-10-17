extends Control

## Presentation is disposable: rules and saves have already committed before playback.
signal finished

var busy: bool = false
var sequence: Tween
var restored: Dictionary = {}
var board: Control
var impact_motion: Tween
var message_motion: Tween
var origin: Vector2


func unit_view(battle: Node, player: int, target: int = -1) -> Control:
	if target >= 0:
		return battle.get_node("YourBench" if player == 0 else "EnemyBench").get_child(target)
	var holder: Node = battle.get_node(
		"Actives/" + ("YourActive" if player == 0 else "EnemyActive") + "/Card"
	)
	return holder.get_child(0) if holder.get_child_count() > 0 else null


func remember(view: Control) -> void:
	if view != null and not restored.has(view):
		restored[view] = [view.position, view.scale, view.modulate, view.pivot_offset]


func cancel() -> void:
	if sequence != null:
		sequence.kill()
	for view: Control in restored:
		if is_instance_valid(view):
			view.position = restored[view][0]
			view.scale = restored[view][1]
			view.modulate = restored[view][2]
			view.pivot_offset = restored[view][3]
	restored.clear()
	if message_motion != null:
		message_motion.kill()
	if impact_motion != null:
		impact_motion.kill()
	$Impact.hide()
	$Burst.emitting = false
	$Burst.hide()
	$Message.hide()
	$InputShield.hide()
	busy = false


func _exit_tree() -> void:
	cancel()


func _burst(view: Control, text: String, color: Color) -> void:
	var center: Vector2 = size / 2.0
	if is_instance_valid(view):
		center = get_global_transform().affine_inverse() * view.get_global_rect().get_center()
	$Burst.show()
	$Burst.position = center
	$Burst.color = color
	$Burst.restart()
	$Message.text = text
	$Message.position = center - Vector2(170, 42)
	$Message.modulate = color
	$Message.show()
	if message_motion != null:
		message_motion.kill()
	message_motion = create_tween().set_parallel(true)
	message_motion.tween_property($Message, "position:y", $Message.position.y - 24, 0.3)
	message_motion.tween_property($Message, "modulate:a", 0.0, 0.3).set_delay(0.15)


func _impact(target: Control, element: String, damage: int) -> void:
	Audio.play_cue(element.to_lower())
	var color: Color = Color("ff9b45")
	if element == "Tide":
		color = Color("51cfff")
	elif element == "Gale":
		color = Color("73e6a4")
	# One bounded emitter becomes rising embers, falling droplets, or wind slashes.
	$Burst.scale = Vector2(1.8, 0.35) if element == "Gale" else Vector2.ONE
	$Burst.gravity = Vector2(0, -120 if element == "Flame" else 180)
	_burst(target, "−%d" % damage, color)
	$Impact.position = $Burst.position
	$Impact.scale = Vector2(0.3, 0.3)
	$Impact.modulate = Color.WHITE
	for shape: CanvasItem in $Impact.get_children():
		shape.visible = shape.name == element
	$Impact.show()
	if impact_motion != null:
		impact_motion.kill()
	impact_motion = create_tween().set_parallel(true)
	(
		impact_motion
		. tween_property($Impact, "scale", Vector2(1.3, 1.3), 0.28)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	impact_motion.tween_property($Impact, "modulate:a", 0.0, 0.28)


func _result(winner: int) -> void:
	var cue: String = "victory" if winner == 0 else ("defeat" if winner == 1 else "draw_result")
	Audio.play_cue(cue)
	_burst(
		null, "VICTORY" if winner == 0 else ("DEFEAT" if winner == 1 else "DRAW"), Color("ffe09a")
	)


func play_action(
	battle: Control,
	before: Dictionary,
	after: Dictionary,
	actor: int,
	action: Dictionary,
	damage: int
) -> void:
	cancel()
	board = battle
	origin = board.position
	var enabled: bool = Profile.data.settings.get("battle_effects", true)
	var attacker: Control = unit_view(battle, actor)
	var target: Control = unit_view(battle, 1 - actor)
	var score: Control = battle.get_node("Score")
	var knockout: bool = int(after.players[actor].points) > int(before.players[actor].points)
	var winner: int = int(after.winner)
	var element: String = "Flame"
	if not before.players[actor].active.is_empty():
		element = Catalog.card(before.players[actor].active.id).element
	for view: Control in [board, attacker, target, score]:
		remember(view)
	if not enabled:
		Audio.play_cue(
			element.to_lower() if action.type == "attack" else _action_cue(before, actor, action)
		)
		if knockout:
			Audio.play_cue("knockout")
		if winner != -2:
			var cue: String = (
				"victory" if winner == 0 else ("defeat" if winner == 1 else "draw_result")
			)
			Audio.play_cue(cue)
		cancel()
		finished.emit()
		return
	busy = true
	$InputShield.position = get_global_transform().affine_inverse() * battle.global_position
	$InputShield.size = battle.size
	$InputShield.show()
	sequence = create_tween()
	if action.type == "attack" and attacker != null and target != null:
		Audio.play_cue("windup")
		var direction: Vector2 = (target.global_position - attacker.global_position).normalized()
		sequence.tween_property(attacker, "position", attacker.position - direction * 12, 0.1)
		sequence.tween_property(attacker, "position", attacker.position + direction * 30, 0.1)
		# All animation steps are authored before playback so cancellation is reliable.
		sequence.tween_callback(_impact.bind(target, element, damage))
		sequence.tween_property(target, "position", target.position + Vector2(8, 0), 0.045)
		sequence.tween_property(target, "position", target.position - Vector2(8, 0), 0.045)
		sequence.tween_property(target, "position", restored[target][0], 0.05)
		if damage >= 60 or knockout:
			sequence.tween_property(board, "position", origin + Vector2(5, 0), 0.035)
			sequence.tween_property(board, "position", origin - Vector2(5, 0), 0.035)
			sequence.tween_property(board, "position", origin, 0.04)
		sequence.tween_property(attacker, "position", restored[attacker][0], 0.1)
		if knockout:
			sequence.tween_callback(
				func() -> void:
					Audio.play_cue("knockout")
					_burst(target, "KNOCKOUT", Color("ffcf66"))
			)
			sequence.tween_property(target, "modulate:a", 0.0, 0.14)
			sequence.tween_property(score, "modulate", Color("e8a52c"), 0.06)
			sequence.tween_property(score, "modulate", Color.WHITE, 0.06)
		_add_healing(before, after, actor)
	else:
		var cue: String = _action_cue(before, actor, action)
		Audio.play_cue(cue)
		var focus: Control = attacker
		if action.has("target") and action.type in ["attach", "support", "retreat", "promote"]:
			focus = unit_view(battle, actor, int(action.target))
		if action.type == "deploy":
			focus = unit_view(battle, actor, before.players[actor].bench.size())
		var caption: String = (
			{
				"attach": "+1 ENERGY",
				"deploy": "DEPLOYED",
				"retreat": "RETREAT",
				"promote": "TO THE FRONT",
				"support": cue.to_upper(),
				"end": "TURN ENDED",
				"concede": "CONCEDED"
			}
			. get(action.type, "")
		)
		if action.type == "support":
			var effect: EffectDefinition = (
				Catalog.card(before.players[actor].hand[int(action.hand)]).effect
			)
			if effect.kind == "DRAW":
				caption = (
					"+%d CARDS"
					% (after.players[actor].hand.size() - before.players[actor].hand.size() + 1)
				)
			elif effect.kind == "MOVE_ENERGY":
				caption = "%d ENERGY → ACTIVE" % effect.amount
			elif effect.kind == "BOOST":
				caption = "+%d DAMAGE" % effect.amount
				focus = attacker
		_burst(focus, caption, Color("8cddff"))
		if focus != null:
			remember(focus)
			focus.pivot_offset = focus.size / 2.0
			sequence.tween_property(focus, "scale", Vector2(1.04, 1.04), 0.11)
			sequence.tween_property(focus, "scale", Vector2.ONE, 0.11)
		else:
			sequence.tween_interval(0.22)
		_add_healing(before, after, actor)
	if winner != -2:
		sequence.tween_callback(_result.bind(winner))
		sequence.tween_interval(0.3)
	elif int(after.turn_count) != int(before.turn_count):
		sequence.tween_callback(
			func() -> void:
				Audio.play_cue("turn")
				_burst(null, "YOUR TURN" if int(after.turn) == 0 else "RIVAL TURN", Color("a9dcff"))
		)
		sequence.tween_interval(0.14)
	sequence.tween_callback(
		func() -> void:
			cancel()
			finished.emit()
	)


func _add_healing(before: Dictionary, after: Dictionary, actor: int) -> void:
	for index: int in range(-1, before.players[actor].bench.size()):
		var old: Dictionary = (
			before.players[actor].active if index < 0 else before.players[actor].bench[index]
		)
		if index >= after.players[actor].bench.size():
			continue
		var current: Dictionary = (
			after.players[actor].active if index < 0 else after.players[actor].bench[index]
		)
		if (
			not old.is_empty()
			and not current.is_empty()
			and current.id == old.id
			and int(current.hp) > int(old.hp)
		):
			var amount: int = int(current.hp) - int(old.hp)
			sequence.tween_callback(
				func() -> void:
					Audio.play_cue("heal")
					_burst(unit_view(board, actor, index), "+%d HP" % amount, Color("78eeac"))
			)
			sequence.tween_interval(0.14)


func _action_cue(before: Dictionary, actor: int, action: Dictionary) -> String:
	if action.type == "support":
		var card: CardDefinition = Catalog.card(before.players[actor].hand[int(action.hand)])
		return {"HEAL": "heal", "DRAW": "draw", "MOVE_ENERGY": "attach", "BOOST": "boost"}.get(
			card.effect.kind, "tap"
		)
	return {"promote": "deploy", "end": "turn", "concede": "tap"}.get(action.type, action.type)
