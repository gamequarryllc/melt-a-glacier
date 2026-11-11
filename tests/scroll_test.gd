extends SceneTree
## Headless test of finger-drag scrolling (DragScroll) in the catalogue:
## godot --headless -s res://tests/scroll_test.gd
## Each touch is sent the way Godot's Input sends a phone's: first a made-up
## mouse event (which is how buttons see taps on iOS), then the touch itself.
## (Input.parse_input_event doesn't reach the viewport headless.)
## The HUD is inset for an iPhone notch throughout. Exits 1 on failure.
## Variables stay untyped (see smoke_test.gd).

var ok := true


func check(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		ok = false


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func():
		print("SCROLL TEST TIMED OUT")
		quit(2))
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _send(ev: InputEvent) -> void:
	root.push_input(ev, true)   # viewport coordinates, as the smoke test does


func _touch(pos: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.device = InputEvent.DEVICE_ID_EMULATION
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	mb.position = pos
	mb.global_position = pos
	_send(mb)
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = pos
	ev.pressed = pressed
	_send(ev)
	await process_frame


func _drag_to(from: Vector2, to: Vector2, steps: int = 8) -> void:
	var last := from
	for s in range(1, steps + 1):
		var p := from.lerp(to, float(s) / steps)
		var mm := InputEventMouseMotion.new()
		mm.device = InputEvent.DEVICE_ID_EMULATION
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		mm.position = p
		mm.global_position = p
		mm.relative = p - last
		_send(mm)
		var ev := InputEventScreenDrag.new()
		ev.index = 0
		ev.position = p
		ev.relative = p - last
		last = p
		_send(ev)
		await process_frame


func _swipe(from: Vector2, to: Vector2) -> void:
	await _touch(from, true)
	await _drag_to(from, to)
	await _touch(to, false)


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.wipe_save()
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await _frames(3)
	var hud = world.hud
	hud.set_touch_mode(true)
	hud.set_safe_inset(Rect2(96.5, 0.0, 96.5, 34.4))
	await _frames(2)

	hud.open_catalogue()
	await _frames(3)
	var box = hud._list_box
	var scroll = box.get_parent()
	check(scroll is ScrollContainer and scroll.has_node("DragScroll"), "the catalogue list has drag scrolling")
	check(scroll.get_v_scroll_bar().custom_minimum_size.x >= 24.0, "and a wide scrollbar")
	# A test button at the top of the list, and plenty below it to scroll.
	var presses := [0]
	var b := Button.new()
	b.text = "Test"
	b.custom_minimum_size = Vector2(0, 90)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): presses[0] += 1)
	box.add_child(b)
	box.move_child(b, 0)
	for i in 12:
		var filler := PanelContainer.new()   # rows are panels: they take the touch first
		filler.custom_minimum_size = Vector2(0, 80)
		box.add_child(filler)
	await _frames(3)
	var bar = scroll.get_v_scroll_bar()
	check(bar.max_value - bar.page > 300.0, "the list is long enough to scroll")

	# A tap on the button presses it and doesn't move the list.
	var at: Vector2 = b.get_global_rect().get_center()
	await _touch(at, true)
	await _touch(at, false)
	check(presses[0] == 1, "a tap presses a button in the list")
	check(scroll.scroll_vertical == 0, "and doesn't scroll it")

	# A tap that wobbles a little (inside the dead zone) still presses it.
	await _touch(at, true)
	await _drag_to(at, at + Vector2(3, 6), 3)
	await _touch(at + Vector2(3, 6), false)
	check(presses[0] == 2, "a slightly wobbly tap still presses it")
	check(scroll.scroll_vertical == 0, "and still doesn't scroll")

	# Dragging up from the button scrolls the list and doesn't press it.
	await _swipe(at, at - Vector2(0, 200))
	var after_drag: int = scroll.scroll_vertical
	check(after_drag >= 150, "dragging up from a button scrolls the list down (%d px)" % after_drag)
	check(presses[0] == 2, "and doesn't press the button")
	await _frames(30)
	check(scroll.scroll_vertical >= after_drag, "the list glides on a little after letting go")

	# Dragging down from a plain row scrolls back up.
	var row: Control = box.get_child(box.get_child_count() - 1)
	var mid: Vector2 = scroll.get_global_rect().get_center()
	await _swipe(mid, mid + Vector2(0, 600))
	await _frames(40)
	check(scroll.scroll_vertical == 0, "dragging down from a row scrolls back to the top")
	check(row != null, "rows stay in place")

	# The button still takes taps after all that.
	at = b.get_global_rect().get_center()
	await _touch(at, true)
	await _touch(at, false)
	check(presses[0] == 3, "and taps still press buttons afterwards")

	# The scrollbar itself still drags the usual way: no list drag starts on it.
	var ds = scroll.get_node("DragScroll")
	var on_bar: Vector2 = bar.get_global_rect().get_center()
	await _touch(on_bar, true)
	await _drag_to(on_bar, on_bar + Vector2(0, 40), 4)
	check(not ds.dragging, "a finger on the scrollbar isn't taken as a list drag")
	await _touch(on_bar + Vector2(0, 40), false)

	hud.close_catalogue()
	await _frames(2)

	# The level menu's list scrolls the same way.
	var menu = load("res://scripts/level_menu.gd").new()
	root.add_child(menu)
	await _frames(2)
	check(menu.find_children("*", "ScrollContainer", true, false).size() == 1 \
		and menu.find_children("*", "ScrollContainer", true, false)[0].has_node("DragScroll"),
		"the Where to next? list has drag scrolling too")
	menu.queue_free()

	print("SCROLL TEST " + ("PASSED" if ok else "FAILED"))
	quit(0 if ok else 1)
