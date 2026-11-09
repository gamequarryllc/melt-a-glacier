class_name ShopRow
extends PanelContainer
## One row in a shop list: icon, title, description, and a buy button.
## `paper` draws it like an entry in a printed catalogue instead: no box, a
## ruled line under it, and the button is a price tag. `icon` is the name of
## one of UiTheme's inked icons ("drop", "flame"...), or any text.

var icon_label: Label
var icon_rect: TextureRect
var title_label: Label
var desc_label: Label
var button: Button
var _normal: StyleBox
var _special: StyleBoxFlat
var _lit := false


func setup(icon: String, title: String, desc: String, paper: bool = false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.2, 0.34)
	sb.set_corner_radius_all(14)
	if paper:
		sb.bg_color = Color(0.93, 0.87, 0.74, 0.0)
		sb.set_corner_radius_all(0)
		sb.border_color = Color(0.6, 0.47, 0.33, 0.55)
		sb.border_width_bottom = 2
	sb.content_margin_left = 6 if paper else 14
	sb.content_margin_right = 6 if paper else 14
	sb.content_margin_top = 6 if paper else 10
	sb.content_margin_bottom = 8 if paper else 10
	add_theme_stylebox_override("panel", sb)
	_normal = sb
	_special = sb.duplicate()
	_special.bg_color = Color(1.0, 0.9, 0.6)
	_special.border_color = Color(0.75, 0.24, 0.16)
	_special.set_border_width_all(3)
	_special.set_corner_radius_all(4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	add_child(h)

	if UiTheme.has_icon(icon):
		icon_rect = UiTheme.icon_rect(icon, 54)
		h.add_child(icon_rect)
	else:
		icon_label = Label.new()
		icon_label.text = icon
		icon_label.add_theme_font_size_override("font_size", 44)
		icon_label.custom_minimum_size = Vector2(64, 0)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(icon_label)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 26)
	if paper:
		title_label.add_theme_font_override("font", UiTheme.display_font())
		title_label.add_theme_color_override("font_color", Color(0.27, 0.16, 0.09))
	v.add_child(title_label)
	desc_label = Label.new()
	desc_label.text = desc
	desc_label.add_theme_font_size_override("font_size", 19)
	desc_label.add_theme_color_override("font_color", Color(0.45, 0.34, 0.25) if paper else Color(0.7, 0.78, 0.9))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(300, 0)
	v.add_child(desc_label)

	button = Button.new()
	UiTheme.no_keyboard(button)
	button.custom_minimum_size = Vector2(190, 76)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.text = ""
	if paper:
		button.custom_minimum_size = Vector2(184, 64)
		button.add_theme_font_size_override("font_size", 23)
		UiTheme.tag_button(button, Color(0.3, 0.62, 0.34))
	h.add_child(button)


func set_title(t: String) -> void:
	if title_label.text != t:
		title_label.text = t


func set_desc(t: String) -> void:
	if desc_label.text != t:
		desc_label.text = t


func set_button(text: String, enabled: bool) -> void:
	if button.text != text:
		button.text = text
	button.disabled = not enabled


func set_highlight(on: bool) -> void:
	## Marks the row as today's special offer (a warm, gently pulsing card).
	if on != _lit:
		_lit = on
		add_theme_stylebox_override("panel", _special if on else _normal)
	if on:
		var t := Time.get_ticks_msec() / 1000.0
		_special.bg_color = Color(1.0, 0.9, 0.6).lerp(Color(1.0, 0.82, 0.5), 0.5 + 0.5 * sin(t * 3.4))
