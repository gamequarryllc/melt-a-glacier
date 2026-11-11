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
	if world.hud._find_card != null and is_instance_valid(world.hud._find_card):
		world.hud._find_card.queue_free()
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
	# Out of the boathouse onto the quay: the buried cabins ahead, the frozen bay to the left.
	await _view(player, "h01_arrival", world.spawn + Vector3(0, 1.55, 0), Vector3(-30.0, 6.5, 0.0))
	await _view(player, "h02_frozen_bay", Vector3(-8.0, 1.55, 14.0), Vector3(-12.0, 6.0, 70.0))
	await _view(player, "h03_glacier", Vector3(-10.0, 1.55, 9.0), Vector3(-36.0, 8.0, -30.0))
	await _view(player, "h04_lighthouse", Vector3(-44.0, 1.55, 16.0), Vector3(-64.0, 13.0, 31.0))
	await _view(player, "h05_from_above", Vector3(4.0, 34.0, 48.0), Vector3(-26.0, 0.0, 4.0))
	# Melting with the Orbital Mirror, then later tools.
	world.force_melt = true
	for t in [0, 1, 3]:
		gs.tool_index = t
		gs.water = 1.0e6 * pow(30.0, t)
		await _view(player, "h06_melt_tool%d" % t, Vector3(-5.0, 1.55, 3.0), Vector3(-19.0, 4.0, -2.0), 45)
	world.force_melt = false
	await _frames(20)
	# Inside the boathouse: the tool wall.
	gs.tool_index = 0
	await _view(player, "h07_shed_tools", Vector3(13.3, 1.55, 12.2), Vector3(13.3, 1.6, 8.0), 20)
	# Kevin has an island of his own out past the eastern cape.
	gs.grant_water(1.0e16)
	gs.buy_helper(2)
	await _frames(30)
	await _view(player, "h08_kevin", Vector3(8.0, 1.55, 19.5), world.helpers.volcano_pos() - Vector3(0, 5.0, 0), 20)
	# A crew at work on the harbour glacier.
	for _i in 8:
		gs.buy_helper(0)
	for _i in 4:
		gs.buy_helper(1)
	await _frames(240)
	await _view(player, "h08b_crew", Vector3(-6.0, 7.0, 8.0), Vector3(-26.0, 6.0, -6.0), 10)
	# The harbour is free; one find's reveal card left up.
	grid.melt_everything()
	await _frames(40)
	await _clear_popups(world)
	await _frames(40)
	var d := 6   # the narwhal
	var at: Vector3 = world._find_markers[d].global_position
	await _view(player, "h09_find", at + Vector3(3.6, 2.6, 3.0), at + Vector3(0, 0.3, 0), 20)
	world.hud.call("_on_discovered", d, 1.0e9) if world.hud.has_method("_on_discovered") else null
	await _frames(30)
	await _shot("h09b_find_card")
	await _clear_popups(world)
	await _view(player, "h10_harbour_free", Vector3(-12.0, 1.55, 16.0), Vector3(-32.0, 2.5, 2.0))
	await _view(player, "h11_cabins", Vector3(-25.0, 1.55, 3.5), Vector3(-37.0, 2.0, -6.0))
	await _view(player, "h12_pier_open", Vector3(1.5, 1.7, 16.5), Vector3(-4.0, 2.0, 27.0))
	# Out on the bay ice.
	var bay = gs.grid
	var top: float = bay.original_top(-6.0, 44.0)
	await _view(player, "h13_on_the_bay", Vector3(-6.0, top + 1.55, 44.0), Vector3(-14.0, top - 1.0, 62.0), 20)
	# All melted: the boats float again.
	bay.melt_everything()
	await _frames(40)
	await _clear_popups(world)
	await _frames(60)
	await _view(player, "h14_harbour_open", Vector3(-3.0, 1.55, 27.0), Vector3(-12.0, 1.5, 70.0), 30)
	await _view(player, "h15_back_to_town", Vector3(-10.0, 1.6, 50.0), Vector3(-25.0, 4.0, 0.0), 10)
	# The level menu.
	world.hud.show_levels()
	await _frames(10)
	await _shot("h16_where_next")
	gs.wipe_save("valley")
	quit(0)
