class_name HUD
extends CanvasLayer
## Portrait race HUD + one-touch controls + start-line lobby overlay.
## No on-screen pedals: hold anywhere to accelerate, drag left/right to steer.

signal retry_requested
signal next_requested
signal menu_requested
signal resume_requested
signal ride_requested
signal garage_requested
signal levels_requested
signal settings_requested

var speedo: Speedo
var speedlines: SpeedLines

var _root: Control
var _pos_label: Label
var _level_label: Label
var _progress: ProgressBar
var _dist_label: Label
var _time_label: Label
var _msg_label: Label
var _nitro: NitroButton
var _lobby: Control
var _hand: HandHint
var _results: Panel
var _results_title: Label
var _results_body: Label
var _pause: Panel
var _pause_btn: Button
var _msg_timer: float = 0.0

var _drive_index: int = -1
var _drive_start_x: float = 0.0
var _nitro_touch: Dictionary = {}

const NITRO_RECT := Rect2(524, 548, 150, 150)
const PAUSE_RECT := Rect2(14, 14, 64, 64)

func _ready() -> void:
	layer = 10
	_build()
	_build_lobby()
	_build_results()
	_build_pause()

func _label(text: String, fs: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _theme() -> Theme:
	var th := Theme.new()
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.10, 0.13, 0.18, 0.96)
	n.border_color = Color(0.44, 0.73, 0.98)
	n.set_border_width_all(2)
	n.set_corner_radius_all(14)
	n.content_margin_left = 18
	n.content_margin_right = 18
	n.content_margin_top = 12
	n.content_margin_bottom = 12
	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.16, 0.34, 0.55)
	h.border_color = Color(0.6, 0.85, 1.0)
	h.set_border_width_all(2)
	h.set_corner_radius_all(14)
	var p := StyleBoxFlat.new()
	p.bg_color = Color(0.06, 0.09, 0.13, 0.94)
	p.border_color = Color(0.3, 0.5, 0.7)
	p.set_border_width_all(2)
	p.set_corner_radius_all(20)
	th.set_stylebox("normal", "Button", n)
	th.set_stylebox("hover", "Button", h)
	th.set_stylebox("pressed", "Button", h)
	th.set_stylebox("panel", "Panel", p)
	th.set_font_size("font_size", "Button", 26)
	return th

# ---------------------------------------------------------------- build

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme()
	add_child(_root)
	var ins := GameState.safe_insets()
	_root.position = Vector2(ins.x, ins.y)
	_root.size = Vector2(720, 1280) - Vector2(ins.x + ins.z, ins.y + ins.w)

	speedlines = SpeedLines.new()
	_root.add_child(speedlines)

	_pause_btn = Button.new()
	_pause_btn.text = "II"
	_pause_btn.position = PAUSE_RECT.position
	_pause_btn.custom_minimum_size = PAUSE_RECT.size
	_pause_btn.size = PAUSE_RECT.size
	_pause_btn.pressed.connect(func(): resume_requested.emit())
	_root.add_child(_pause_btn)

	_pos_label = _label("1st", 44, Color(1, 0.85, 0.3))
	_pos_label.position = Vector2(92, 18)
	_root.add_child(_pos_label)

	_level_label = _label("LEVEL 1", 30, Color(1, 0.9, 0.4))
	_level_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_level_label.position = Vector2(-180, 18)
	_level_label.custom_minimum_size = Vector2(360, 36)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_level_label)

	_progress = ProgressBar.new()
	_progress.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_progress.position = Vector2(-180, 58)
	_progress.custom_minimum_size = Vector2(360, 18)
	_progress.size = Vector2(360, 18)
	_progress.max_value = 100.0
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_progress)

	_dist_label = _label("", 20, Color(0.9, 0.95, 0.8))
	_dist_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_dist_label.position = Vector2(-180, 82)
	_dist_label.custom_minimum_size = Vector2(360, 26)
	_dist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_dist_label)

	speedo = Speedo.new()
	speedo.position = Vector2(452, 14)
	speedo.custom_minimum_size = Vector2(254, 158)
	speedo.size = Vector2(254, 158)
	_root.add_child(speedo)

	_time_label = _label("00:00.00", 26)
	_time_label.position = Vector2(20, 92)
	_root.add_child(_time_label)

	_nitro = NitroButton.new()
	_nitro.position = NITRO_RECT.position
	_nitro.custom_minimum_size = NITRO_RECT.size
	_nitro.size = NITRO_RECT.size
	_root.add_child(_nitro)

	_msg_label = _label("", 52, Color(1, 0.95, 0.5))
	_msg_label.set_anchors_preset(Control.PRESET_CENTER)
	_msg_label.position = Vector2(-300, -260)
	_msg_label.custom_minimum_size = Vector2(600, 70)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_msg_label)

func _build_lobby() -> void:
	_lobby = Control.new()
	_lobby.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lobby.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_lobby)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-260, -330)
	panel.custom_minimum_size = Vector2(520, 130)
	panel.size = Vector2(520, 130)
	panel.theme = _theme()
	_lobby.add_child(panel)

	var t := _label("HOLD TO RIDE", 40, Color(1, 0.9, 0.4))
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.position = Vector2(-260, 0)
	t.custom_minimum_size = Vector2(520, 50)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(t)

	_hand = HandHint.new()
	_hand.position = Vector2(150, 62)
	_hand.custom_minimum_size = Vector2(220, 54)
	_hand.size = Vector2(220, 54)
	panel.add_child(_hand)

	# bottom navigation
	var g := Button.new()
	g.text = "GARAGE"
	g.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	g.position = Vector2(24, -110)
	g.custom_minimum_size = Vector2(200, 84)
	g.pressed.connect(func(): garage_requested.emit())
	_lobby.add_child(g)
	var l := Button.new()
	l.text = "LEVELS"
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.position = Vector2(-100, -110)
	l.custom_minimum_size = Vector2(200, 84)
	l.pressed.connect(func(): levels_requested.emit())
	_lobby.add_child(l)
	var s := Button.new()
	s.text = "SETTINGS"
	s.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	s.position = Vector2(-224, -110)
	s.custom_minimum_size = Vector2(200, 84)
	s.pressed.connect(func(): settings_requested.emit())
	_lobby.add_child(s)

func _build_results() -> void:
	_results = Panel.new()
	_results.set_anchors_preset(Control.PRESET_CENTER)
	_results.position = Vector2(-290, -360)
	_results.custom_minimum_size = Vector2(580, 720)
	_results.size = Vector2(580, 720)
	_results.visible = false
	_results.theme = _theme()
	add_child(_results)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_right = -40
	box.offset_top = 40
	box.offset_bottom = -40
	box.add_theme_constant_override("separation", 22)
	_results.add_child(box)
	_results_title = _label("FINISH", 54, Color(1, 0.85, 0.3))
	_results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_results_title)
	_results_body = _label("", 30)
	_results_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_results_body)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 20)
	box.add_child(sp)
	var nb := Button.new()
	nb.text = "NEXT LEVEL"
	nb.custom_minimum_size = Vector2(0, 84)
	nb.pressed.connect(func(): next_requested.emit())
	box.add_child(nb)
	var rb := Button.new()
	rb.text = "RETRY"
	rb.custom_minimum_size = Vector2(0, 76)
	rb.pressed.connect(func(): retry_requested.emit())
	box.add_child(rb)
	var mb := Button.new()
	mb.text = "MAIN MENU"
	mb.custom_minimum_size = Vector2(0, 76)
	mb.pressed.connect(func(): menu_requested.emit())
	box.add_child(mb)

func _build_pause() -> void:
	_pause = Panel.new()
	_pause.set_anchors_preset(Control.PRESET_CENTER)
	_pause.position = Vector2(-260, -280)
	_pause.custom_minimum_size = Vector2(520, 560)
	_pause.size = Vector2(520, 560)
	_pause.visible = false
	_pause.theme = _theme()
	add_child(_pause)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_right = -40
	box.offset_top = 40
	box.offset_bottom = -40
	box.add_theme_constant_override("separation", 20)
	_pause.add_child(box)
	var t := _label("PAUSED", 46, Color(1, 0.85, 0.3))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	for pair in [["RESUME", "resume"], ["RESTART", "retry"], ["GARAGE", "garage"], ["MAIN MENU", "menu"]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(0, 80)
		match pair[1]:
			"resume": b.pressed.connect(func(): resume_requested.emit())
			"retry": b.pressed.connect(func(): retry_requested.emit())
			"garage": b.pressed.connect(func(): garage_requested.emit())
			"menu": b.pressed.connect(func(): menu_requested.emit())
		box.add_child(b)

# ---------------------------------------------------------------- one-touch input

func set_lobby(on: bool) -> void:
	_lobby.visible = on
	_nitro.visible = not on

func _input(event: InputEvent) -> void:
	if _results.visible or _pause.visible:
		_release_drive()
		return
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			_on_press(t.index, t.position)
		else:
			_on_release(t.index)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position)
	elif event is InputEventMouseButton:
		var m: InputEventMouseButton = event
		if m.button_index == MOUSE_BUTTON_LEFT:
			if m.pressed:
				_on_press(0, m.position)
			else:
				_on_release(0)
	elif event is InputEventMouseMotion and _drive_index == 0:
		_on_drag(0, event.position)

func _on_press(index: int, pos: Vector2) -> void:
	var p := pos - _root.position
	if NITRO_RECT.has_point(p):
		_nitro_touch[index] = true
		Input.action_press("nitro")
		return
	if _lobby.visible:
		ride_requested.emit()
	# hold anywhere to drive; dragging steers
	_drive_index = index
	_drive_start_x = pos.x
	GameState.touch_drive = true
	GameState.touch_steer = 0.0

func _on_drag(index: int, pos: Vector2) -> void:
	if index == _drive_index:
		GameState.touch_steer = clampf((pos.x - _drive_start_x) / 110.0, -1.0, 1.0)

func _on_release(index: int) -> void:
	if _nitro_touch.has(index):
		Input.action_release("nitro")
		_nitro_touch.erase(index)
	if index == _drive_index:
		_drive_index = -1
		GameState.touch_drive = false
		GameState.touch_steer = 0.0

func _release_drive() -> void:
	_drive_index = -1
	GameState.touch_drive = false
	GameState.touch_steer = 0.0
	for k in _nitro_touch.keys():
		Input.action_release("nitro")
	_nitro_touch.clear()

# ---------------------------------------------------------------- runtime

func set_level(level: int) -> void:
	_level_label.text = "LEVEL %d" % level

func update_state(speed_kmh: float, lap: int, total_laps: int, time_s: float,
		position: int, total_racers: int) -> void:
	_pos_label.text = _ordinal(position)
	_time_label.text = _fmt_time(time_s)

func set_speed(kmh: float, top: float) -> void:
	if speedo != null:
		speedo.set_speed(kmh, top)

func set_nitro(charge: float) -> void:
	if _nitro != null:
		_nitro.set_charge(charge)

func set_speedlines(v: float) -> void:
	if speedlines != null:
		speedlines.set_intensity(v)

func set_progress(done_m: float, total_m: float) -> void:
	var t: float = maxf(1.0, total_m)
	var d: float = minf(done_m, t)
	_progress.value = clampf(d / t * 100.0, 0.0, 100.0)
	_dist_label.text = "%.2f / %.2f km" % [d / 1000.0, t / 1000.0]

func flash(text: String) -> void:
	_msg_label.text = text
	_msg_timer = 2.0

func show_results(time_s: float, stars_earned: int, level: int) -> void:
	_results_title.text = "FINISH"
	var star_str := ""
	for i in range(3):
		star_str += "*" if i < stars_earned else "-"
	_results_body.text = "RACE REWARD: %d\nTime: %s\nRating: %s\n\nBest: %s" % [
		stars_earned * 30, _fmt_time(time_s), star_str, _fmt_time(GameState.get_best_time(level))]
	_results.visible = true

func show_pause() -> void:
	_pause.visible = true

func hide_pause() -> void:
	_pause.visible = false

func _process(delta: float) -> void:
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			_msg_label.text = ""

func _ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [n, suffix]

func _fmt_time(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	var cs := int((t - floor(t)) * 100.0)
	return "%02d:%02d.%02d" % [m, s, cs]

# ---------------------------------------------------------------- widgets

class NitroButton extends Control:
	var charge: float = 1.0

	func set_charge(v: float) -> void:
		charge = clampf(v, 0.0, 1.0)
		queue_redraw()

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color(0.04, 0.05, 0.08, 0.55))
		draw_circle(c, r - 5.0, Color(0.30, 0.62, 0.95, 0.25 + 0.35 * charge))
		draw_arc(c, r - 5.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 44, Color(0.45, 0.85, 1.0, 0.95), 7.0, true)
		# lightning bolt
		var s: float = r * 0.5
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(s * 0.25, -s), c + Vector2(-s * 0.75, s * 0.15),
			c + Vector2(-s * 0.05, s * 0.15), c + Vector2(-s * 0.25, s),
			c + Vector2(s * 0.75, -s * 0.15), c + Vector2(s * 0.05, -s * 0.15)]), Color(1, 1, 1, 0.95))
		var font: Font = ThemeDB.fallback_font
		draw_string(font, c + Vector2(-r, r * 0.72), str(int(round(charge * 100.0))),
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 22, Color(0.9, 0.95, 1.0))

class HandHint extends Control:
	var t: float = 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var x: float = size.x * 0.5 + sin(t * 2.2) * size.x * 0.32
		var c := Vector2(x, size.y * 0.5)
		draw_circle(c, 15.0, Color(1, 1, 1, 0.9))
		draw_circle(c, 8.0, Color(0.3, 0.5, 0.8, 0.9))
		# motion arrows
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-30, 0), c + Vector2(-14, -9), c + Vector2(-14, 9)]), Color(1, 1, 1, 0.6))
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(30, 0), c + Vector2(14, -9), c + Vector2(14, 9)]), Color(1, 1, 1, 0.6))
