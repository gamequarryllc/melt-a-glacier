extends SceneTree
## Screenshots of the valley itself (ground, stream, mountains, lake), for
## checking the scenery:
##   xvfb-run -s "-screen 0 1688x780x24" godot --rendering-driver opengl3 --resolution 1688x780 -s res://tests/scenery_shots.gd -- /tmp/shots
## (Untyped on purpose; see smoke_test.gd.)

var out_dir := "/tmp/shots"


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


func _view(player, name: String, eye: Vector3, target: Vector3) -> void:
	player.position = eye - Vector3(0, 1.55, 0)
	player.velocity = Vector3.ZERO
	var d := target - eye
	player.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _frames(6)
	await _shot(name)


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.wipe_save("valley")
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	var player = world.player
	var grid = world.grid
	world.hud.visible = false
	player.set_physics_process(false)
	await _frames(10)
	await _view(player, "s01_spawn", Vector3(world.SPAWN.x, 1.55, world.SPAWN.z), Vector3(0.0, 5.0, -10.0))
	await _view(player, "s02_ground_close", Vector3(-6.0, 1.55, 12.0), Vector3(-3.0, 0.0, 6.5))
	await _view(player, "s03_stream_source", Vector3(-7.5, 1.55, 9.5), Vector3(-2.5, 0.6, 3.0))
	await _view(player, "s04_stream_down", Vector3(-3.0, 1.55, 6.0), Vector3(-11.0, 0.0, 22.0))
	await _view(player, "s05_mountains_left", Vector3(8.0, 1.55, 12.0), Vector3(-60.0, 22.0, -30.0))
	await _view(player, "s06_mountains_right", Vector3(-8.0, 1.55, 12.0), Vector3(60.0, 22.0, -30.0))
	await _view(player, "s07_lake_side", Vector3(0.0, 1.55, 14.0), Vector3(0.0, 6.0, 70.0))
	await _view(player, "s08_from_glacier", Vector3(0.0, grid.surface_y(0.0, -12.0) + 1.6, -12.0), Vector3(0.0, 6.0, 60.0))
	await _view(player, "s09_side_wall", Vector3(-12.0, 1.55, 14.0), Vector3(-30.0, 7.0, 0.0))
	await _view(player, "s10_behind", Vector3(14.0, 1.55, -33.0), Vector3(-10.0, 8.0, -45.0))
	await _view(player, "s10b_falls", Vector3(6.0, 1.55, -32.5), Vector3(13.5, 5.0, -43.0))
	await _view(player, "s10c_cave", Vector3(-4.2, 1.55, 7.5), Vector3(-2.5, 0.7, 1.0))
	# The village is free: green valley.
	grid.melt_everything()
	await _frames(40)
	for c in world.hud.popups.get_children():
		c.queue_free()
	await _frames(40)
	await _view(player, "s11_green_village", Vector3(3.0, 1.55, 10.0), Vector3(0.0, 4.0, -16.0))
	await _view(player, "s12_green_ground", Vector3(-6.0, 1.55, 12.0), Vector3(-3.0, 0.0, 6.5))
	await _view(player, "s13_green_stream", Vector3(-3.0, 1.55, 2.0), Vector3(-11.0, 0.0, 22.0))
	await _view(player, "s13b_village_river", Vector3(3.0, 1.55, -1.0), Vector3(12.0, 2.5, -36.0))
	await _view(player, "s13c_falls_free", Vector3(8.0, 1.55, -27.0), Vector3(13.2, 5.0, -43.0))
	# Everything melted: open water.
	gs.grid.melt_everything()
	await _frames(40)
	for c in world.hud.popups.get_children():
		c.queue_free()
	await _frames(40)
	await _view(player, "s14_lake_free", Vector3(-10.0, 1.55, 27.0), Vector3(5.0, 3.0, 80.0))
	await _view(player, "s15_lake_shore", Vector3(-14.0, 1.55, 31.0), Vector3(-10.0, 0.0, 38.0))
	await _view(player, "s16_shore_along", Vector3(6.0, 1.55, 25.5), Vector3(40.0, 0.5, 34.0))
	await _view(player, "s17_back_to_village", Vector3(2.0, 1.55, 26.0), Vector3(0.0, 6.0, -20.0))
	gs.wipe_save("valley")
	quit(0)
