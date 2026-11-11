class_name DragScroll
extends Node
## Finger-drag scrolling for a ScrollContainer: put a finger anywhere on the
## list (on a row, a button, a picture) and drag it up or down. The list
## follows the finger and keeps gliding a little after you let go.
##
## Godot's own ScrollContainer only drags when the touch lands on the container
## itself; every row of the catalogue is a panel or a button that takes the
## touch first, so on the iPhone the only way to scroll was the thin bar.
##
## A tap still presses the button under it: the list only starts to move once
## the finger has gone DEAD_ZONE past where it landed. From then on the drag
## belongs to the list, and the button it started on is let go of without
## being pressed.
##
## Use DragScroll.attach(scroll). It also makes the scrollbar a fat brown
## handle that is easy to grab.

const DEAD_ZONE := 14.0       # how far a finger moves before a tap becomes a drag
const FRICTION := 5.0         # how fast a flicked list slows down (per second)
const MIN_GLIDE := 30.0       # px/s: slower than this, a glide stops
const BAR_WIDTH := 26.0

const BAR_TRACK := Color(0.45, 0.29, 0.17, 0.18)
const BAR_GRAB := Color(0.45, 0.29, 0.17, 0.85)
const BAR_GRAB_HOT := Color(0.55, 0.36, 0.21, 0.95)

var scroll: ScrollContainer
var dragging := false          # the finger has passed the dead zone: the list follows it

var _finger := -2              # touch index (or MOUSE for a mouse) on the list; NONE when none
var _start := Vector2.ZERO     # where the finger landed
var _last_y := 0.0
var _last_time := 0
var _velocity := 0.0           # px/s, for the glide after letting go
var _remainder := 0.0          # sub-pixel scroll the int scroll_vertical can't hold
var _pushing := false

const NONE := -2
const MOUSE := -3


static func attach(sc: ScrollContainer) -> DragScroll:
	var d := DragScroll.new()
	d.scroll = sc
	d.name = "DragScroll"
	sc.add_child(d, false, Node.INTERNAL_MODE_BACK)
	d.style_bar(sc.get_v_scroll_bar())
	return d


static func style_bar(bar: VScrollBar) -> void:
	## A wide, rounded brown handle on a faint track.
	bar.custom_minimum_size.x = BAR_WIDTH
	var track := StyleBoxFlat.new()
	track.bg_color = BAR_TRACK
	track.set_corner_radius_all(int(BAR_WIDTH / 2))
	track.content_margin_left = BAR_WIDTH / 2
	track.content_margin_right = BAR_WIDTH / 2
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var g := StyleBoxFlat.new()
		g.bg_color = BAR_GRAB if state == "grabber" else BAR_GRAB_HOT
		g.set_corner_radius_all(int(BAR_WIDTH / 2))
		g.content_margin_top = BAR_WIDTH   # never shorter than a fingertip
		g.content_margin_bottom = BAR_WIDTH
		bar.add_theme_stylebox_override(state, g)


func _ready() -> void:
	set_process(false)


func _max_scroll() -> float:
	var bar := scroll.get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)


func _on_list(pos: Vector2) -> bool:
	## pos (in the viewport) is on the list, but not on its scrollbar, which
	## keeps working the usual way.
	if scroll == null or not scroll.is_visible_in_tree():
		return false
	if not scroll.get_global_rect().has_point(pos):
		return false
	var bar := scroll.get_v_scroll_bar()
	if bar.visible and bar.get_global_rect().grow(4.0).has_point(pos):
		return false
	return true


func _input(event: InputEvent) -> void:
	if _pushing:
		return   # our own "the pointer has left" note to the button
	if scroll == null or not scroll.is_visible_in_tree():
		_finger = NONE
		dragging = false
		return
	# On a phone each touch also arrives as a made-up mouse event. The real
	# touch drives the scrolling; the mouse copy only needs to be kept away
	# from the button while the list is being dragged.
	var emulated := event.device == InputEvent.DEVICE_ID_EMULATION
	if event is InputEventScreenTouch:
		_press(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		if event.index == _finger:
			_move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# (The phone's copy of a lift-off still reaches the button, which no
		# longer counts it as a press once the list has been dragged.)
		if not emulated:
			_press(MOUSE, event.position, event.pressed)
	elif event is InputEventMouseMotion:
		if not emulated and _finger == MOUSE:
			_move(event.position)
		if dragging:
			# Keep the button under the finger from seeing the finger move back
			# over it, and keep ScrollContainer's own drag out of it.
			get_viewport().set_input_as_handled()


func _press(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if _finger != NONE or not _on_list(pos):
			return
		_finger = index
		_start = pos
		_last_y = pos.y
		_last_time = Time.get_ticks_usec()
		_velocity = 0.0
		_remainder = 0.0
		dragging = false
		set_process(false)   # a finger on a gliding list stops it
	elif index == _finger:
		_finger = NONE
		if dragging:
			dragging = false
			if absf(_velocity) > MIN_GLIDE:
				set_process(true)


func _move(pos: Vector2) -> void:
	if _finger == NONE:
		return
	if not dragging:
		if absf(pos.y - _start.y) < DEAD_ZONE:
			return
		if _max_scroll() <= 0.0:
			return   # nothing to scroll: leave the touch to whatever it's on
		dragging = true
		_last_y = pos.y
		_let_go_of_button()
		return
	var now := Time.get_ticks_usec()
	var dy := pos.y - _last_y
	var dt := maxf(0.001, (now - _last_time) / 1000000.0)
	_velocity = lerpf(_velocity, -dy / dt, 0.5)
	_last_y = pos.y
	_last_time = now
	_scroll_by(-dy)
	get_viewport().set_input_as_handled()


func _scroll_by(px: float) -> bool:
	## Moves the list by px; false once it hits the top or bottom.
	var want := scroll.scroll_vertical + _remainder + px
	var clamped := clampf(want, 0.0, _max_scroll())
	scroll.scroll_vertical = int(clamped)
	_remainder = clamped - scroll.scroll_vertical
	return is_equal_approx(want, clamped)


func _let_go_of_button() -> void:
	## The button the drag started on was pressed down but not yet let go.
	## Tell it the pointer has left (far off screen): a button only counts a
	## press if the pointer is still on it when it's let go.
	var mm := InputEventMouseMotion.new()
	mm.device = InputEvent.DEVICE_ID_EMULATION
	mm.position = Vector2(-100000, -100000)
	mm.global_position = mm.position
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	_pushing = true
	get_viewport().push_input(mm)
	_pushing = false


func _process(delta: float) -> void:
	if not _scroll_by(_velocity * delta):
		_velocity = 0.0
	_velocity *= exp(-FRICTION * delta)
	if absf(_velocity) < MIN_GLIDE:
		set_process(false)
