class_name Speedo
extends Control
## Digital speed readout with a curved green-yellow-red speed bar, plus a
## nitro charge arc. Drawn as vectors (no textures).

var speed: float = 0.0
var max_speed: float = 240.0
var boost: float = 0.0
var _display: float = 0.0

func set_speed(kmh: float, top: float) -> void:
	speed = kmh
	max_speed = maxf(60.0, top)

func set_boost(v: float) -> void:
	boost = clampf(v, 0.0, 1.0)
	queue_redraw()

func _process(delta: float) -> void:
	var target: float = clampf(speed, 0.0, max_speed)
	if absf(target - _display) > 0.4:
		_display = lerpf(_display, target, clampf(delta * 9.0, 0.0, 1.0))
		queue_redraw()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var w: float = size.x
	var h: float = size.y

	# curved speed bar across the top of the control
	var a0 := deg_to_rad(200.0)
	var a1 := deg_to_rad(340.0)
	var c := Vector2(w * 0.5, h * 0.92)
	var r: float = minf(w * 0.5, h * 0.85) - 6.0
	draw_arc(c, r, a0, a1, 40, Color(0, 0, 0, 0.5), 14.0, true)
	var t: float = clampf(_display / max_speed, 0.0, 1.0)
	var col := Color(0.35, 0.9, 0.45)
	if t > 0.6:
		col = Color(1.0, 0.82, 0.25)
	if t > 0.85:
		col = Color(1.0, 0.32, 0.22)
	if t > 0.01:
		draw_arc(c, r, a0, lerpf(a0, a1, t), 40, col, 14.0, true)
	# nitro arc just inside
	if boost > 0.01:
		draw_arc(c, r - 13.0, a0, lerpf(a0, a1, boost), 36, Color(0.35, 0.78, 1.0, 0.95), 6.0, true)

	# digital readout
	draw_string(font, Vector2(0, h * 0.62), str(int(round(_display))),
		HORIZONTAL_ALIGNMENT_CENTER, w, 52, Color.WHITE)
	draw_string(font, Vector2(0, h * 0.82), "km/h",
		HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(0.85, 0.88, 0.95))
