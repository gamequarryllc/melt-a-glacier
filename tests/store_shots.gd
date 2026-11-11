extends SceneTree
## Renders the App Store screenshots, at iPhone 6.9" size, with the phone HUD
## inset for the notch the way a real iPhone shows it:
##   xvfb-run -s "-screen 0 2868x1320x24" godot --rendering-driver opengl3 \
##     --resolution 2868x1320 --fixed-fps 30 -s res://tests/store_shots.gd -- /tmp/store
## Also saves the Catalogue screen, which is the review screenshot the two
## in-app purchases need.
## Add "harbor" after the folder for Frozen Harbor's two shots (07, 08) instead.
## (Untyped on purpose; see smoke_test.gd.)

var out_dir := "/tmp/store"
var gs
var world
var hud
var player


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	if args.has("harbor"):
		_run_harbor.call_deferred()
	else:
		_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)   # the store refuses screenshots with an alpha channel
	img.save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _aim_at(target: Vector3) -> void:
	var eye: Vector3 = player.position + Vector3(0, 1.55, 0)
	var d := target - eye
	player.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


func _stand(at: Vector3, look: Vector3) -> void:
	player.position = at
	player.velocity = Vector3.ZERO
	player.unstick()
	_aim_at(look)


func _tool(i: int, heat: int = 0, nozzle: int = 0, reach: int = 0) -> void:
	gs.tool_index = i
	gs.upgrade_levels["heat"] = heat
	gs.upgrade_levels["nozzle"] = nozzle
	gs.upgrade_levels["reach"] = reach
	gs.changed.emit()


func _carve(field, at: Vector3, radius: float) -> void:
	for _i in 4:
		field.damage_sphere(at, radius, 1e9)


func _slice_top(field, above: float) -> void:
	for i in field.f.size():
		if field.f[i] > 0.0 and field.point_pos(i).y > above:
			field.f[i] = 0.0
	field._count()
	field._update_col_top(0, field.nx - 1, 0, field.nz - 1)
	for ci in field._chunks.size():
		field._dirty[ci] = true
	field.flush()


func _clear_cards() -> void:
	## Takes down the find card and any toasts, so they don't hang over the next shot.
	if hud._find_card != null and is_instance_valid(hud._find_card):
		hud._find_card.queue_free()
	for c in hud.toast_box.get_children():
		c.queue_free()


func _close_popups() -> void:
	for c in hud.popups.get_children():
		hud.popups.remove_child(c)
		c.queue_free()
	player.input_enabled = true


func _run() -> void:
	gs = root.get_node("GameState")
	gs.wipe_save()
	gs.owns_remove_ads_2x = false
	gs.owns_helpers_2x = false
	world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	hud = world.hud
	player = world.player
	var grid = world.grid
	hud.set_touch_mode(true)
	hud.set_safe_inset(Rect2(96.5, 0.0, 96.5, 34.4))   # iPhone 16 Pro Max, landscape
	gs.tutorial_step = 4
	await _frames(10)

	var front_z := 4.0
	while front_z > -10.0 and grid.surface_y(1.0, front_z) < 1.3:
		front_z -= 0.1

	# --- Halfway through the village glacier ---------------------------------------
	_slice_top(grid, 3.6)
	await _frames(4)

	# --- A find breaking out of the ice --------------------------------------------
	var d := 8   # the Frozen Mammoth
	var spot: Vector3 = world._find_spots[d]
	_tool(3, 8, 4, 4)
	var stand := spot + Vector3(1.6, 0.0, 4.2)
	_stand(Vector3(stand.x, grid.surface_y(stand.x, stand.z) + 0.1, stand.z), spot + Vector3(0, 0.7, 0))
	await _frames(20)
	gs.water = 41300.0
	_carve(grid, spot + Vector3(0, 1.0, 0), 3.0)
	_carve(grid, spot + Vector3(0.8, 1.4, 2.0), 2.4)
	grid.flush()
	gs.water = 61300.0
	await _frames(26)
	_aim_at(spot + Vector3(0, 0.7, 0))
	await _frames(4)
	await _shot("03_find")
	await _frames(220)
	_clear_cards()

	# --- The hero shot: melting towards the church tower ---------------------------
	gs.water = 86400.0
	# Somewhere along the front where the flame lands on ice (not in the stream's cave).
	for x in [5.0, 6.5, 3.5, 8.0, -4.0, -6.0]:
		var fz := 6.0
		while fz > -10.0 and grid.surface_y(x, fz) < 1.5:
			fz -= 0.1
		_stand(Vector3(x - 1.2, 0.0, fz + 4.2), Vector3(x, 1.3, fz - 0.6))
		await _frames(6)
		if player.target.hit:
			break
	await _frames(14)
	world.force_melt = true
	await _frames(26)
	print("hero hit: ", player.target.hit)
	await _shot("01_melt")
	world.force_melt = false
	await _frames(10)

	# --- The shed: the tool wall ---------------------------------------------------
	var shed = world.shed
	_tool(2, 8, 4, 4)
	gs.water = 112000.0
	player.position = Vector3(12.3, 0.0, 11.6)
	player.velocity = Vector3.ZERO
	_aim_at(shed.item("tool", 3).node.global_position)
	await _frames(12)
	await _shot("02_shed")

	# --- Helpers at work -----------------------------------------------------------
	_tool(3, 8, 4, 4)
	gs.helper_counts[0] = 8
	gs.helper_counts[1] = 4
	gs.changed.emit()
	gs.water = 241000.0
	await _frames(30)
	# Call the crew over to one patch of the glacier, the church behind them.
	var centre := Vector3(-5.0, 0.0, -5.0)
	var crew: Array = []
	for t in [0, 1]:
		var have := 0
		for w in world.helpers._walkers:
			if w.type == t and have < (5 if t == 0 else 2):
				crew.append(w)
				have += 1
	var places := [Vector2(-1.6, 0.4), Vector2(-0.5, -0.8), Vector2(0.6, 0.3), Vector2(1.6, -0.6),
		Vector2(0.0, 1.3), Vector2(2.9, -1.6), Vector2(-3.0, -1.2)]
	for n in crew.size():
		var w = crew[n]
		var p := centre + Vector3(places[n].x, 0.0, places[n].y)
		p.y = grid.surface_y(p.x, p.z)
		w.pos = p
		w.node.position = p
		w.target = Vector3.INF
	var cam := centre + Vector3(-0.8, 0.0, 3.9)
	_stand(Vector3(cam.x, grid.surface_y(cam.x, cam.z) + 0.1, cam.z), centre + Vector3(0, grid.surface_y(centre.x, centre.z) + 0.9, 0))
	await _frames(24)
	# A "+4.3" drifting up right in front of the lens would cover half the picture.
	for f in world._floats:
		if f.node.visible and f.node.position.distance_to(player.position + Vector3(0, 1.55, 0)) < 3.0:
			f.node.visible = false
	await _shot("04_helpers")

	# --- The village is free -------------------------------------------------------
	grid.melt_everything()
	await _frames(30)
	_close_popups()
	_clear_cards()
	gs.water = 3120000.0
	_tool(4, 12, 6, 6)
	_stand(Vector3(2.0, 0.0, -4.0), Vector3(0.0, 2.0, -16.0))
	await _frames(60)
	await _shot("05_village")

	# --- The frozen lake -----------------------------------------------------------
	var lake = gs.grid
	_slice_top(lake, 6.5)
	gs.water = 14700000.0
	_stand(Vector3(-4.0, 7.0, 44.0), Vector3(2.0, 3.0, 66.0))
	await _frames(20)
	world.force_melt = true
	await _frames(24)
	await _shot("06_lake")
	world.force_melt = false
	await _frames(10)

	# --- The Catalogue (the review screenshot for the two purchases) ---------------
	_stand(Vector3(3.0, 0.0, 15.0), Vector3(0.0, 1.5, 30.0))
	await _frames(10)
	_clear_cards()
	hud.open_catalogue()
	await _frames(12)
	hud.set_process(false)
	_strip_test_tags(hud)
	await _frames(2)
	await _shot("iap_review_catalogue")
	gs.wipe_save()
	quit(0)


func _run_harbor() -> void:
	## Frozen Harbor, the second map: the buried cabins, then the fleet in the bay.
	gs = root.get_node("GameState")
	gs.maps_won = ["valley"]
	gs.wipe_save("harbor")
	gs.owns_remove_ads_2x = false
	gs.owns_helpers_2x = false
	world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	hud = world.hud
	player = world.player
	var grid = world.grid
	hud.set_touch_mode(true)
	hud.set_safe_inset(Rect2(96.5, 0.0, 96.5, 34.4))   # iPhone 16 Pro Max, landscape
	gs.tutorial_step = 4
	await _frames(10)
	hud.set_coach("")

	# --- The Dragon Puppet on the harbour glacier, two cabins half dug out ----------
	for c in [Vector3(-20.5, 2.0, 9.5), Vector3(-24.5, 2.5, 8.0), Vector3(-28.5, 3.0, 7.0), Vector3(-33.0, 3.0, 6.5)]:
		_carve(grid, c, 4.8)
	grid.flush()
	_tool(1, 8, 4, 4)
	gs.water = 412.0e6
	_stand(Vector3(-12.0, 0.0, 14.5), Vector3(-29.0, 8.0, 2.0))
	await _frames(20)
	_clear_cards()
	world.force_melt = true
	await _frames(30)
	print("harbour hit: ", player.target.hit)
	await _shot("07_harbor")
	world.force_melt = false
	await _frames(10)

	# --- The fishing cabins, free -------------------------------------------------
	grid.melt_everything()
	await _frames(40)
	_close_popups()
	_clear_cards()
	_tool(3, 12, 6, 6)
	gs.water = 9.64e9
	_stand(Vector3(-25.0, 0.0, 3.2), Vector3(-37.0, 3.0, -6.5))
	await _frames(120)
	_close_popups()
	_clear_cards()
	await _frames(4)
	await _shot("08_cabins")
	gs.maps_won = []
	gs.wipe_save("valley")
	quit(0)


func _strip_test_tags(n: Node) -> void:
	## The stand-in store in dev builds writes "(test)" after prices.
	if n is Button and (n as Button).text.ends_with(" (test)"):
		(n as Button).text = (n as Button).text.trim_suffix(" (test)")
	for c in n.get_children():
		_strip_test_tags(c)
