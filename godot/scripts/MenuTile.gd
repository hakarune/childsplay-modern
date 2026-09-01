extends Button
## MenuTile — one square icon tile on the launcher grid (Design Policy §F).
##
## Draws its own themed background so idle / hover-focus / pressed / selected
## read by LIGHTNESS and SHAPE, not a hue or a thin border (§F.2.3):
##   idle           -> surface
##   hover / focus   -> surface_alt  + 3px accent ring
##   pressed         -> accent fill  + 4px inset  (the icon also scales down)
##   selected        -> accent ring  + a corner check glyph
##
## The icon fills the tile minus a uniform margin (§F.1.2); the caption is a
## band inside the bottom edge over a scrim (§F.1.3).

const RING := 3.0
const PRESS_INSET := 4.0

var game_id := ""
var _icon: Texture2D = null
var _title := ""
var selected := false


func setup(id: String, title: String, icon: Texture2D) -> void:
	game_id = id
	_title = title
	_icon = icon
	tooltip_text = title
	focus_mode = Control.FOCUS_ALL
	flat = true                       # suppress the default Button skin; we draw
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# repaint on state changes
	if not mouse_entered.is_connected(queue_redraw):
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var hot := has_focus() or is_hovered()
	var down := is_pressed()
	var radius := 18.0

	# --- background -------------------------------------------------------
	var fill := GameContext.c("surface")
	if down:
		fill = GameContext.c("accent")
	elif hot:
		fill = GameContext.c("surface_alt")
	var body := r
	if down:
		body = r.grow(-PRESS_INSET)
	draw_style_rounded(body, fill, radius)

	if hot and not down:
		_draw_ring(body, radius, GameContext.c("accent"), RING)
	if selected:
		_draw_ring(body, radius, GameContext.c("accent"), RING)

	# --- icon ----------------------------------------------------------
	var margin: float = clampf(size.x * 0.10, 12.0, 28.0)
	var label_band: float = clampf(size.y * 0.20, 26.0, 44.0)
	var box := Rect2(
		body.position + Vector2(margin, margin),
		Vector2(body.size.x - margin * 2.0, body.size.y - margin - label_band))
	if down:
		box = box.grow(-3.0)
	if _icon != null:
		var tex_size := Vector2(_icon.get_width(), _icon.get_height())
		var s: float = minf(box.size.x / tex_size.x, box.size.y / tex_size.y)
		var draw_size := tex_size * s
		var pos := box.position + (box.size - draw_size) * 0.5
		draw_texture_rect(_icon, Rect2(pos, draw_size), false)
	else:
		draw_style_rounded(box, GameContext.c("surface_alt"), 12.0)

	# --- caption band ---------------------------------------------------
	var font := get_theme_default_font()
	var fsize := 22
	var band := Rect2(
		body.position + Vector2(0, body.size.y - label_band - 6),
		Vector2(body.size.x, label_band + 6))
	var scrim := GameContext.c("bg")
	scrim.a = 0.0
	var scrim2 := GameContext.c("bg")
	scrim2.a = 0.55
	draw_rect(band, scrim2)
	var text_col := GameContext.c("text") if not down else GameContext.c("card")
	var tw := font.get_string_size(_title, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize).x
	draw_string(font, Vector2(body.position.x + (body.size.x - tw) * 0.5,
			band.position.y + label_band * 0.75),
		_title, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, text_col)

	# --- selected corner check ---------------------------------------
	if selected:
		var c := body.position + Vector2(body.size.x - 22, 22)
		draw_circle(c, 12, GameContext.c("accent"))
		draw_string(font, c + Vector2(-7, 6), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			GameContext.c("card"))


func draw_style_rounded(rect: Rect2, col: Color, rad: float) -> void:
	# Godot has no direct rounded-rect fill; approximate with a body rect +
	# four corner circles. Cheap and crisp at these sizes.
	var rr: float = minf(rad, minf(rect.size.x, rect.size.y) * 0.5)
	draw_rect(Rect2(rect.position + Vector2(rr, 0), Vector2(rect.size.x - rr * 2, rect.size.y)), col)
	draw_rect(Rect2(rect.position + Vector2(0, rr), Vector2(rect.size.x, rect.size.y - rr * 2)), col)
	for corner in [
		rect.position + Vector2(rr, rr),
		rect.position + Vector2(rect.size.x - rr, rr),
		rect.position + Vector2(rr, rect.size.y - rr),
		rect.position + Vector2(rect.size.x - rr, rect.size.y - rr),
	]:
		draw_circle(corner, rr, col)


func _draw_ring(rect: Rect2, rad: float, col: Color, w: float) -> void:
	var rr: float = minf(rad, minf(rect.size.x, rect.size.y) * 0.5)
	# top / bottom / left / right edges
	draw_rect(Rect2(rect.position + Vector2(rr, 0), Vector2(rect.size.x - rr * 2, w)), col)
	draw_rect(Rect2(rect.position + Vector2(rr, rect.size.y - w), Vector2(rect.size.x - rr * 2, w)), col)
	draw_rect(Rect2(rect.position + Vector2(0, rr), Vector2(w, rect.size.y - rr * 2)), col)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - w, rr), Vector2(w, rect.size.y - rr * 2)), col)
	for corner in [
		rect.position + Vector2(rr, rr),
		rect.position + Vector2(rect.size.x - rr, rr),
		rect.position + Vector2(rr, rect.size.y - rr),
		rect.position + Vector2(rect.size.x - rr, rect.size.y - rr),
	]:
		draw_arc(corner, rr - w * 0.5, 0, TAU, 24, col, w)
