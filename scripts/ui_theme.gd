class_name UiTheme
extends RefCounted
## Shared look for every menu: fonts (with emoji), colours, and the
## hand-painted pieces the HUD is made of (art/ui/make_ui.py draws them): a
## stained wooden plaque, a sheet of paper, painted boards for buttons (tinted
## to any colour), hanging price tags, a progress bar in a carved slot, and a
## set of inked icons (icon()) used instead of emoji. Titles and buttons use
## Lilita One, a chunky sign-painter style face; everything else is Nunito
## ExtraBold.

const EMOJI_FONT_PATH := "res://fonts/NotoColorEmoji-subset.ttf"
const DISPLAY_FONT_PATH := "res://fonts/LilitaOne-Regular.ttf"
const BODY_FONT_PATH := "res://fonts/Nunito-Variable.ttf"
const INK := Color(0.23, 0.14, 0.09)          # outlines and text on paper
const CREAM := Color(1.0, 0.96, 0.86)         # text on wood and enamel

static var _soft_dot: Texture2D
static var _display: Font
static var _tex := {}


static func install_emoji_font() -> void:
	## Emoji are the placeholder art. Make a bundled colour-emoji font a fallback
	## of the default font so every Label, Label3D and draw_string can show them.
	## The body font becomes the default everywhere (Labels, Label3D signs).
	if _display != null:
		return   # already installed
	var emoji := load(EMOJI_FONT_PATH) as FontFile
	emoji.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	var body := FontVariation.new()
	body.base_font = load(BODY_FONT_PATH)
	var ts := TextServerManager.get_primary_interface()
	body.variation_opentype = {ts.name_to_tag("wght"): 800}
	body.fallbacks = [emoji]
	var display := FontVariation.new()
	display.base_font = load(DISPLAY_FONT_PATH)
	display.spacing_glyph = 1
	display.fallbacks = [emoji]
	_display = display
	ThemeDB.fallback_font = body
	ThemeDB.get_default_theme().default_font = body


static func display_font() -> Font:
	install_emoji_font()
	return _display


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://ui/%s.png" % name)
	return _tex[name]


static func _nine(name: String, margin: float, content: Vector4, tint: Color = Color.WHITE) -> StyleBoxTexture:
	## content = left, top, right, bottom padding inside the image.
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	sb.set_texture_margin_all(margin)
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	sb.modulate_color = tint
	# Tile the middle, so wood grain and paper fibres don't smear when stretched.
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return sb


static func icon(name: String) -> Texture2D:
	## One of the inked HUD icons in ui/icon/ ("drop", "flame", "book", ...).
	return tex("icon/" + name)


static func has_icon(name: String) -> bool:
	return name != "" and name.is_valid_identifier() and ResourceLoader.exists("res://ui/icon/%s.png" % name)


static func icon_rect(name: String, px: float) -> TextureRect:
	## An icon as a square control, `px` on a side.
	var r := TextureRect.new()
	r.texture = icon(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # drawn at 96 px, shown much smaller
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func wood_sign() -> StyleBoxTexture:
	return _nine("wood_sign", 26.0, Vector4(20, 12, 24, 16))


static func tag(color: Color) -> StyleBoxTexture:
	## A hanging price tag (pointed end and string hole on the left), tinted.
	var sb := StyleBoxTexture.new()
	sb.texture = tex("tag")
	sb.texture_margin_left = 30.0
	sb.texture_margin_right = 14.0
	sb.texture_margin_top = 14.0
	sb.texture_margin_bottom = 18.0
	sb.content_margin_left = 34.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 13.0
	sb.modulate_color = color
	return sb


static func paper(pad: float = 26.0) -> StyleBoxTexture:
	return _nine("paper", 28.0, Vector4(pad, pad, pad, pad + 4.0))


static func cover() -> StyleBoxFlat:
	## The leather cover a big paper page sits on (the catalogue, the level menu).
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.43, 0.18, 0.13)
	sb.border_color = INK
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(7)
	sb.set_content_margin_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(0, 6)
	return sb


static func rule_rect(height: float = 22.0) -> TextureRect:
	## A hand-inked divider: a wavy line with a red diamond in the middle.
	var r := TextureRect.new()
	r.texture = tex("rule")
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(0, height)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func tag_button(b: Button, color: Color) -> void:
	## A button that is a price tag (the catalogue's rows).
	no_keyboard(b)
	b.add_theme_stylebox_override("normal", tag(color))
	b.add_theme_stylebox_override("hover", tag(color.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", tag(color.darkened(0.14)))
	b.add_theme_stylebox_override("disabled", tag(Color(0.74, 0.69, 0.6)))
	b.add_theme_color_override("font_disabled_color", Color(0.98, 0.95, 0.88))


static func bar_styles(bar: ProgressBar, fill: Color) -> void:
	bar.add_theme_stylebox_override("background", _nine("bar_frame", 12.0, Vector4.ZERO))
	var f := _nine("bar_fill", 10.0, Vector4.ZERO, fill)
	f.expand_margin_left = -5
	f.expand_margin_right = -5
	f.expand_margin_top = -5
	f.expand_margin_bottom = -5
	bar.add_theme_stylebox_override("fill", f)


static func enamel(color: Color, pressed: bool = false) -> StyleBoxTexture:
	## A painted board with cut corners and an ink outline, tinted `color`.
	## (Still called enamel from the old glossy look.)
	return _nine("button_down" if pressed else "button", 20.0,
			Vector4(18, 9 if not pressed else 13, 18, 17 if not pressed else 13), color)


static func outlined(c: Control, size: int, color: Color = CREAM, outline: int = 8, display: bool = true) -> void:
	## Sign-painter lettering in the display font: a thin ink outline and a
	## hard drop shadow under it, so it reads over snow and sky alike.
	if display:
		c.add_theme_font_override("font", display_font())
	c.add_theme_font_size_override("font_size", size)
	c.add_theme_color_override("font_color", color)
	c.add_theme_color_override("font_outline_color", INK)
	var o := maxi(4, int(outline * 0.6))
	c.add_theme_constant_override("outline_size", o)
	if c is Label:
		c.add_theme_color_override("font_shadow_color", INK)
		c.add_theme_constant_override("shadow_outline_size", o)
		c.add_theme_constant_override("shadow_offset_x", 0)
		c.add_theme_constant_override("shadow_offset_y", maxi(2, size / 10))


static func plain(text: String) -> String:
	## `text` without emoji (the HUD draws its own icons): toasts and hints
	## written with a leading emoji come out as plain words.
	var out := ""
	for i in text.length():
		var c := text.unicode_at(i)
		if c == 0x200D or (c >= 0xFE00 and c <= 0xFE0F) or c >= 0x1F000 or (c >= 0x2600 and c <= 0x27BF) \
				or (c >= 0x2300 and c <= 0x23FF) or (c >= 0x2B00 and c <= 0x2BFF):
			continue
		out += text[i]
	while out.contains("  "):
		out = out.replace("  ", " ")
	var lines := out.split("\n")
	for k in lines.size():
		lines[k] = lines[k].strip_edges()
	return "\n".join(lines)


static func soft_dot() -> Texture2D:
	## A soft round blob for particles (steam, flames, sparks). Built from an
	## Image with mipmaps: a GradientTexture2D rendered some particles black on WebGL.
	if _soft_dot == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
		img.generate_mipmaps()
		_soft_dot = ImageTexture.create_from_image(img)
	return _soft_dot


static func flat(color: Color, radius: int = 12, margin: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	return s


static func make_theme() -> Theme:
	install_emoji_font()
	var t := Theme.new()
	t.default_font = ThemeDB.fallback_font
	t.default_font_size = 24
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", INK)
	t.set_font("font", "Button", display_font())
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", CREAM)
	t.set_color("font_pressed_color", "Button", CREAM)
	t.set_color("font_disabled_color", "Button", Color(0.85, 0.82, 0.76))
	t.set_color("font_outline_color", "Button", INK)
	t.set_constant("outline_size", "Button", 5)
	t.set_constant("h_separation", "Button", 8)
	var blue := Color(0.36, 0.6, 0.86)
	t.set_stylebox("normal", "Button", enamel(blue))
	t.set_stylebox("hover", "Button", enamel(blue.lightened(0.12)))
	t.set_stylebox("pressed", "Button", enamel(blue.darkened(0.1), true))
	t.set_stylebox("disabled", "Button", enamel(Color(0.6, 0.58, 0.55)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	return t


static func no_keyboard(b: BaseButton) -> void:
	## Buttons are for clicks and taps only. A button the mouse clicked keeps
	## keyboard focus, and Space (jump) or Enter would press it again: letting
	## go of Space after flying hit "Respawn" and sent you back to the start.
	b.focus_mode = Control.FOCUS_NONE


static func colored_button(b: Button, color: Color, _radius: int = 14) -> void:
	## An enamel button in `color` (see enamel). The radius is from the old flat look.
	no_keyboard(b)
	b.add_theme_stylebox_override("normal", enamel(color))
	b.add_theme_stylebox_override("hover", enamel(color.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", enamel(color.darkened(0.1), true))
	b.add_theme_stylebox_override("disabled", enamel(color.lerp(Color(0.6, 0.58, 0.55), 0.7)))


static func sign_label(l: Label3D, color: Color = CREAM) -> void:
	## Floating lettering in the world (the shed's sign, Kevin's name, +💧
	## numbers): the display font with an ink outline, like the HUD.
	l.font = display_font()
	l.modulate = color
	l.outline_modulate = INK
