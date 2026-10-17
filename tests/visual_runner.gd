extends Node

var canvas: SubViewport


func _ready() -> void:
	await get_tree().process_frame
	Profile.data = Profile.fresh_data()
	canvas = SubViewport.new()
	canvas.size = (
		Vector2i(720, 1560) if OS.get_cmdline_user_args().has("--tall") else Vector2i(720, 1280)
	)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(canvas)
	var ui: Control = load("res://scenes/main.tscn").instantiate()
	canvas.add_child(ui)
	await _capture("starter")
	ui._choose_starter(0)
	await _capture("home")
	ui.show_screen("Packs")
	ui._open_pack()
	await _capture("pack")
	ui._skip_reveal()
	await _capture("rare")
	ui._finish_pack()
	await _capture("collection")
	ui.show_screen("Decks")
	await _capture("decks")
	ui.show_screen("Setup")
	Profile.data.tutorial = true
	ui._start_battle()
	ui.get_node("AITimer").stop()
	ui.rules.state.turn = 0
	ui.rules.state.turn_count = 3
	ui.rules.state.energy_ready = true
	ui.rules.state.players[0].active.energy = 2
	ui.rules.state.players[0].bench = [{"id": "cinderhorn", "hp": 80, "energy": 1, "boost": 0}]
	ui._render_battle()
	await _capture("battle")
	ui._inspect("emberlyn")
	await _capture("detail")
	ui.show_screen("Settings")
	await _capture("settings")
	# Exercise touch-equivalent signals and result presentation.
	ui.rules.state.winner = 0
	ui.rules.state.reason = "Three points"
	Profile.settle_match(ui.rules.state)
	ui.show_screen("Results")
	await _capture("results")
	print("VISUAL RUN COMPLETE")
	Audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()


func _capture(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://builds/previews")
	canvas.get_texture().get_image().save_png(
		(
			"res://builds/previews/%s%s.png"
			% [label, "-tall" if OS.get_cmdline_user_args().has("--tall") else ""]
		)
	)
