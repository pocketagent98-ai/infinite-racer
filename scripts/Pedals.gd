class_name Pedals
extends Control
## On-screen controls drawn as proper game buttons: round buttons with icons
## for steering / handbrake / nitro, and pedal-shaped GAS / BRAKE buttons.
## Hit-testing is done by the HUD so several fingers can be held at once.

var zones: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_zones(z: Array) -> void:
	zones = z
	queue_redraw()

func _process(_delta: float) -> void:
	if not zones.is_empty():
		queue_redraw()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for z in zones:
		var r: Rect2 = z["rect"]
		var accent: Color = z.get("accent", Color(1, 1, 1))
		var action: String = String(z.get("action", ""))
		var pressed: bool = action != "" and Input.is_action_pressed(action)
		var fill_a: float = 0.40 if pressed else 0.18
		var ring_a: float = 0.95 if pressed else 0.55
		var shape: String = String(z.get("shape", "circle"))

		if shape == "circle":
			var c: Vector2 = r.position + r.size * 0.5
			var rad: float = minf(r.size.x, r.size.y) * 0.5
			draw_circle(c, rad, Color(0.04, 0.05, 0.08, 0.5))
			draw_circle(c, rad - 4.0, Color(accent.r, accent.g, accent.b, fill_a))
			draw_arc(c, rad - 4.0, 0.0, TAU, 56, Color(accent.r, accent.g, accent.b, ring_a), 4.0, true)
			if pressed:
				draw_arc(c, rad - 1.0, 0.0, TAU, 56, Color(1, 1, 1, 0.35), 2.0, true)
			_draw_icon(c, rad * 0.5, String(z.get("icon", "")), Color(1, 1, 1, 0.95), font, String(z.get("text", "")))
		else:
			var outer := StyleBoxFlat.new()
			outer.bg_color = Color(0.04, 0.05, 0.08, 0.5)
			outer.set_corner_radius_all(24)
			draw_style_box(outer, r)
			var inner := StyleBoxFlat.new()
			inner.bg_color = Color(accent.r, accent.g, accent.b, fill_a)
			inner.border_color = Color(accent.r, accent.g, accent.b, ring_a)
			inner.set_border_width_all(4)
			inner.set_corner_radius_all(22)
			draw_style_box(inner, r.grow(-5.0))
			var c2: Vector2 = r.position + Vector2(r.size.x * 0.5, r.size.y * 0.38)
			_draw_icon(c2, r.size.y * 0.20, String(z.get("icon", "")), Color(1, 1, 1, 0.92), font, "")
			draw_string(font, r.position + Vector2(0, r.size.y * 0.80), String(z.get("text", "")),
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(1, 1, 1, 0.95))

func _draw_icon(c: Vector2, s: float, icon: String, col: Color, font: Font, fallback_text: String) -> void:
	match icon:
		"left":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s, 0), c + Vector2(s * 0.25, -s * 0.85), c + Vector2(s * 0.25, s * 0.85)]), col)
		"right":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(s, 0), c + Vector2(-s * 0.25, -s * 0.85), c + Vector2(-s * 0.25, s * 0.85)]), col)
		"up":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -s), c + Vector2(-s * 0.85, s * 0.6), c + Vector2(s * 0.85, s * 0.6)]), col)
		"down":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, s), c + Vector2(-s * 0.85, -s * 0.6), c + Vector2(s * 0.85, -s * 0.6)]), col)
		"bolt":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(s * 0.25, -s), c + Vector2(-s * 0.75, s * 0.15),
				c + Vector2(-s * 0.05, s * 0.15), c + Vector2(-s * 0.25, s),
				c + Vector2(s * 0.75, -s * 0.15), c + Vector2(s * 0.05, -s * 0.15)]), col)
		_:
			if fallback_text != "":
				draw_string(font, c + Vector2(-s * 2.0, s * 0.55), fallback_text,
					HORIZONTAL_ALIGNMENT_CENTER, s * 4.0, 24, col)
