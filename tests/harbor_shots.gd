extends SceneTree
## Screenshots of Frozen Harbor (the second map), with the HUD:
##   xvfb-run -s "-screen 0 1688x780x24" godot --rendering-driver opengl3 --resolution 1688x780 -s res://tests/harbor_shots.gd -- /tmp/harbor
## (Untyped on purpose; see smoke_test.gd.)

var out_dir := "/tmp/harbor"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _view(player, name: String, eye: Vector3, target: Vector3, frames: int = 6) -> void:
	player.position = eye - Vector3(0, 1.55, 0)
	player.velocity = Vector3.ZERO
	var d := target - eye
	player.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _frames(frames)
	await _shot(name)


func _clear_popups(world) -> void:
	for c in world.hud.popups.get_children():
		c.queue_free()
	await _frames(3)
	world.player.input_enabled = true


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.maps_won = ["valley"]
	gs.wipe_save("harbor")
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	var player = world.player
	var grid = world.grid
	world.hud.set_touch_mode(true)   # the phone HUD
	await _frames(10)
	world.hud.set_coach("")
	await _view(player, "h01_arrival", Vector3(world.SPAWN.x, 1.55, world.SPAWN.z), Vector3(0.0, 7.0, -10.0))
	await _view(player, "h02_lighthouse", Vector3(-6.0, 1.55, 9.0), Vector3(1.0, 13.0, -11.0))
	await _view(player, "h03_bay_frozen", Vector3(0.0, 2.5, 18.0), Vector3(0.0, 6.0, 70.0))
	# Melting with the Orbital Mirror, then later tools.
	world.force_melt = true
	for t in [0, 1, 3]:
		gs.tool_index = t
		gs.water = 1.0e6 * pow(30.0, t)
		await _view(player, "h04_melt_tool%d" % t, Vector3(-4.0, 1.55, 14.0), Vector3(-1.0, 4.0, -2.0), 45)
	world.force_melt = false
	await _frames(20)
	# Inside the shed: the tool wall.
	gs.tool_index = 0
	await _view(player, "h05_shed_tools", Vector3(13.3, 1.55, 12.2), Vector3(13.3, 1.6, 8.0), 20)
	await _view(player, "h05b_shed_bench", Vector3(13.3, 1.55, 10.4), Vector3(13.3, 0.9, 14.0), 10)
	# The harbour is free; one find's reveal card left up.
	grid.melt_everything()
	await _frames(40)
	await _clear_popups(world)
	await _frames(40)
	var d := 6   # the narwhal
	var at: Vector3 = world._find_markers[d].global_position
	await _view(player, "h06_find", at + Vector3(2.5, 2.4, 5.0), at + Vector3(0, 0.3, 0), 20)
	world.hud.call("_on_discovered", d, 1.0e9) if world.hud.has_method("_on_discovered") else null
	await _frames(30)
	await _shot("h06b_find_card")
	await _clear_popups(world)
	await _view(player, "h07_harbour_free", Vector3(3.0, 1.55, 6.0), Vector3(0.0, 5.0, -16.0))
	await _view(player, "h08_rorbuer", Vector3(-12.0, 1.55, -9.0), Vector3(-2.0, 2.0, -20.0))
	await _view(player, "h09_bay_gate_open", Vector3(2.0, 2.5, 18.0), Vector3(0.0, 6.0, 60.0))
	var bay = gs.grid
	# All melted: the boats float again.
	bay.melt_everything()
	await _frames(40)
	await _clear_popups(world)
	await _frames(60)
	await _view(player, "h11_harbour_open", Vector3(-8.0, 1.55, 27.0), Vector3(0.0, 2.0, 60.0), 30)
	await _view(player, "h12_boats_close", Vector3(-12.0, 1.55, 33.0), Vector3(-3.0, 1.5, 52.0), 10)
	# The level menu.
	world.hud.show_levels()
	await _frames(10)
	await _shot("h13_where_next")
	gs.wipe_save("valley")
	quit(0)
