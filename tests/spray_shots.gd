extends SceneTree
## Shots of every tool's spray: first person and from the side, with no
## upgrades and with Heat Output, Wider Nozzle and Longer Reach maxed.
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/spray_shots.gd -- /tmp/spray [tool=N] [phone]
## "phone" renders at 844x390 like an iPhone held sideways.
## (Untyped on purpose; see smoke_test.gd.)

var out_dir := "/tmp/spray"


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


func _aim_at(player, target: Vector3) -> void:
	var eye: Vector3 = player.position + Vector3(0, 1.55, 0)
	var d := target - eye
	player.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("phone"):
		root.size = Vector2i(844, 390)
	var only := -1
	for a in args:
		if a.begins_with("tool="):
			only = int(a.substr(5))
	var gs = root.get_node("GameState")
	gs.wipe_save()
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	var player = world.player
	var grid = world.grid
	world.hud.visible = false
	gs.debug_speed = 0.0   # no melting: every shot aims at the same untouched ice
	await _frames(10)
	var side_cam := Camera3D.new()
	side_cam.fov = 55.0
	world.add_child(side_cam)

	var front_z := 4.0
	while front_z > -10.0 and grid.surface_y(1.0, front_z) < 1.3:
		front_z -= 0.1
	for tool_i in 6:
		if only >= 0 and tool_i != only:
			continue
		for maxed in [false, true]:
			gs.tool_index = tool_i
			for u in gs.upgrade_levels.keys():
				gs.upgrade_levels[u] = 0
			if maxed:
				for k in ["heat", "nozzle", "reach"]:
					gs.upgrade_levels[k] = int(gs.upgrade_def(k).max)
			var back := 2.6 + (3.0 if tool_i >= 3 else 0.0) + (3.0 if maxed and tool_i >= 3 else 0.0)
			if tool_i == 5:
				back = 9.0
			var tgt := Vector3(1.0, 1.0, front_z - 0.8)
			player.position = Vector3(1.4, 0.0, front_z + back)
			player.velocity = Vector3.ZERO
			player.unstick()
			_aim_at(player, tgt)
			world.force_melt = true
			await _frames(40)
			var tag := "%d_%s" % [tool_i, "max" if maxed else "base"]
			await _shot(tag + "_fp")
			# From the side, a little above.
			var eye: Vector3 = player.position + Vector3(0, 1.55, 0)
			var mid: Vector3 = eye.lerp(tgt, 0.5)
			var span: float = eye.distance_to(tgt)
			side_cam.global_position = mid + Vector3(-span * 0.8 - 1.2, 0.9, 0.6)
			side_cam.look_at(mid, Vector3.UP)
			side_cam.current = true
			await _frames(6)
			await _shot(tag + "_side")
			side_cam.current = false
			player.camera.current = true
			world.force_melt = false
			await _frames(15)
	quit()
