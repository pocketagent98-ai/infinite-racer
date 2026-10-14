extends CanvasLayer
## Portrait menu: Level Select, Garage (3D turntable) and Settings.
## Can also run as an overlay on top of the race lobby.

signal start_level(level: int, car_index: int)
signal quit_requested

var overlay_mode: bool = false

var _root: Control
var _main_panel: VBoxContainer
var _level_panel: Control
var _garage_panel: Control
var _settings_panel: Control
var _stats_label: Label
var _level_grid: GridContainer
var _preview_label: Label
var _sub: SubViewport
var _car_pivot: Node3D
var _spin: float = 0.6
var _dragging: bool = false
var _bar_speed: ProgressBar
var _bar_accel: ProgressBar
var _bar_handling: ProgressBar
var _lock_label: Label
var _sfx: AudioStreamPlayer

func _ready() -> void:
	layer = 20
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = Sfx.click()
	_sfx.volume_db = linear_to_db(clampf(GameState.volume, 0.001, 1.0) * 0.7)
	add_child(_sfx)
	_build()
	_show_main()

func _click() -> void:
	if _sfx != null:
		_sfx.play()

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
	p.bg_color = Color(0.05, 0.07, 0.11, 0.92)
	p.border_color = Color(0.2, 0.3, 0.42)
	p.set_border_width_all(2)
	p.set_corner_radius_all(20)
	th.set_stylebox("normal", "Button", n)
	th.set_stylebox("hover", "Button", h)
	th.set_stylebox("pressed", "Button", h)
	th.set_stylebox("panel", "Panel", p)
	th.set_font_size("font_size", "Button", 26)
	return th

func _label(text: String, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _button(text: String, fs: int = 26) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 76)
	b.add_theme_font_size_override("font_size", fs)
	b.pressed.connect(_click)
	return b

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _theme()
	add_child(_root)
	var ins := GameState.safe_insets()
	_root.position = Vector2(ins.x, ins.y)
	_root.size = Vector2(720, 1280) - Vector2(ins.x + ins.z, ins.y + ins.w)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.06, 0.09, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var title := _label("INFINITE RACER", 48, Color(1, 0.85, 0.3))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-360, 70)
	title.custom_minimum_size = Vector2(720, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)

	_build_main()
	_build_levels()
	_build_garage()
	_build_settings()

func _build_main() -> void:
	_main_panel = VBoxContainer.new()
	_main_panel.set_anchors_preset(Control.PRESET_CENTER)
	_main_panel.position = Vector2(-250, -180)
	_main_panel.custom_minimum_size = Vector2(500, 460)
	_main_panel.add_theme_constant_override("separation", 18)
	_root.add_child(_main_panel)
	var cont := _button("PLAY  -  Level %d" % GameState.unlocked_level)
	cont.pressed.connect(func(): start_level.emit(GameState.unlocked_level, GameState.selected_car))
	_main_panel.add_child(cont)
	var lv := _button("LEVELS")
	lv.pressed.connect(_show_levels)
	_main_panel.add_child(lv)
	var gr := _button("GARAGE")
	gr.pressed.connect(_show_garage)
	_main_panel.add_child(gr)
	var st := _button("SETTINGS")
	st.pressed.connect(_show_settings)
	_main_panel.add_child(st)
	var q := _button("QUIT")
	q.pressed.connect(func(): quit_requested.emit())
	_main_panel.add_child(q)
	_stats_label = _label("", 20, Color(0.7, 0.78, 0.88))
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_panel.add_child(_stats_label)

func _build_levels() -> void:
	_level_panel = Control.new()
	_level_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_level_panel.visible = false
	_root.add_child(_level_panel)
	var header := _label("SELECT LEVEL", 40, Color(1, 0.85, 0.3))
	header.set_anchors_preset(Control.PRESET_CENTER_TOP)
	header.position = Vector2(-360, 170)
	header.custom_minimum_size = Vector2(720, 56)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_panel.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_CENTER)
	scroll.position = Vector2(-320, -280)
	scroll.custom_minimum_size = Vector2(640, 700)
	scroll.size = Vector2(640, 700)
	_level_panel.add_child(scroll)
	_level_grid = GridContainer.new()
	_level_grid.columns = 3
	_level_grid.add_theme_constant_override("h_separation", 14)
	_level_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_level_grid)
	var back := _button("BACK")
	back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back.position = Vector2(-140, -130)
	back.custom_minimum_size = Vector2(280, 76)
	back.pressed.connect(_show_main)
	_level_panel.add_child(back)

func _build_garage() -> void:
	_garage_panel = Control.new()
	_garage_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_garage_panel.visible = false
	_root.add_child(_garage_panel)
	var header := _label("GARAGE", 40, Color(1, 0.85, 0.3))
	header.set_anchors_preset(Control.PRESET_CENTER_TOP)
	header.position = Vector2(-360, 160)
	header.custom_minimum_size = Vector2(720, 56)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_garage_panel.add_child(header)

	var svc := SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_CENTER_TOP)
	svc.position = Vector2(-330, 240)
	svc.custom_minimum_size = Vector2(660, 420)
	svc.size = Vector2(660, 420)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(_garage_input)
	_garage_panel.add_child(svc)
	_sub = SubViewport.new()
	_sub.size = Vector2i(660, 420)
	_sub.own_world_3d = true
	_sub.transparent_bg = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(_sub)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.6, 7.4)
	cam.rotation_degrees = Vector3(-11, 0, 0)
	cam.fov = 50.0
	_sub.add_child(cam)
	var l1 := DirectionalLight3D.new()
	l1.rotation_degrees = Vector3(-45, -35, 0)
	l1.light_energy = 1.3
	_sub.add_child(l1)
	var l2 := DirectionalLight3D.new()
	l2.rotation_degrees = Vector3(-25, 150, 0)
	l2.light_energy = 0.5
	_sub.add_child(l2)
	_car_pivot = Node3D.new()
	_sub.add_child(_car_pivot)

	var prev := _button("<", 34)
	prev.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prev.position = Vector2(-360, 420)
	prev.custom_minimum_size = Vector2(70, 100)
	prev.pressed.connect(func(): _garage_step(-1))
	_garage_panel.add_child(prev)
	var nxt := _button(">", 34)
	nxt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	nxt.position = Vector2(290, 420)
	nxt.custom_minimum_size = Vector2(70, 100)
	nxt.pressed.connect(func(): _garage_step(1))
	_garage_panel.add_child(nxt)

	_preview_label = _label("", 28, Color(0.85, 0.9, 1.0))
	_preview_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_preview_label.position = Vector2(-360, 700)
	_preview_label.custom_minimum_size = Vector2(720, 36)
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_garage_panel.add_child(_preview_label)
	_lock_label = _label("", 22, Color(1, 0.7, 0.4))
	_lock_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_lock_label.position = Vector2(-360, 740)
	_lock_label.custom_minimum_size = Vector2(720, 30)
	_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_garage_panel.add_child(_lock_label)

	var stats_box := VBoxContainer.new()
	stats_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	stats_box.position = Vector2(-300, 790)
	stats_box.custom_minimum_size = Vector2(600, 200)
	stats_box.add_theme_constant_override("separation", 14)
	_garage_panel.add_child(stats_box)
	_bar_speed = _stat_row(stats_box, "TOP SPEED")
	_bar_accel = _stat_row(stats_box, "ACC")
	_bar_handling = _stat_row(stats_box, "HANDLING")

	var sel := _button("SELECT THIS CAR")
	sel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sel.position = Vector2(-190, -220)
	sel.custom_minimum_size = Vector2(380, 76)
	sel.pressed.connect(_garage_select)
	_garage_panel.add_child(sel)
	var back := _button("BACK")
	back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back.position = Vector2(-140, -130)
	back.custom_minimum_size = Vector2(280, 76)
	back.pressed.connect(_show_main)
	_garage_panel.add_child(back)

func _stat_row(parent: Node, name: String) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := _label(name, 20, Color(0.8, 0.86, 0.95))
	l.custom_minimum_size = Vector2(190, 28)
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(380, 24)
	row.add_child(bar)
	parent.add_child(row)
	return bar

func _build_settings() -> void:
	_settings_panel = Control.new()
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.visible = false
	_root.add_child(_settings_panel)
	var header := _label("SETTINGS", 40, Color(1, 0.85, 0.3))
	header.set_anchors_preset(Control.PRESET_CENTER_TOP)
	header.position = Vector2(-360, 200)
	header.custom_minimum_size = Vector2(720, 56)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_panel.add_child(header)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-300, -240)
	box.custom_minimum_size = Vector2(600, 520)
	box.add_theme_constant_override("separation", 26)
	_settings_panel.add_child(box)
	box.add_child(_setting_row("GRAPHICS", _quality_option()))
	box.add_child(_setting_row("VOLUME", _volume_slider()))
	box.add_child(_setting_row("CAMERA SHAKE", _shake_check()))
	var rp := _button("RESET PROGRESS", 24)
	rp.pressed.connect(func(): GameState.reset_progress())
	box.add_child(rp)
	var back := _button("BACK")
	back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back.position = Vector2(-140, -130)
	back.custom_minimum_size = Vector2(280, 76)
	back.pressed.connect(_show_main)
	_settings_panel.add_child(back)

func _setting_row(name: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := _label(name, 24, Color(0.85, 0.9, 1.0))
	l.custom_minimum_size = Vector2(260, 56)
	row.add_child(l)
	control.custom_minimum_size = Vector2(280, 56)
	row.add_child(control)
	return row

func _quality_option() -> OptionButton:
	var qb := OptionButton.new()
	qb.add_item("Low")
	qb.add_item("Medium")
	qb.add_item("High")
	qb.selected = GameState.quality
	qb.item_selected.connect(func(i): GameState.quality = i; GameState.save_game())
	return qb

func _volume_slider() -> HSlider:
	var vs := HSlider.new()
	vs.min_value = 0.0
	vs.max_value = 1.0
	vs.step = 0.05
	vs.value = GameState.volume
	vs.value_changed.connect(func(v): GameState.volume = v; GameState.save_game())
	return vs

func _shake_check() -> CheckButton:
	var cb := CheckButton.new()
	cb.button_pressed = GameState.shake_enabled
	cb.toggled.connect(func(v): GameState.shake_enabled = v; GameState.save_game())
	return cb

# ---------------------------------------------------------------- panels

func show_panel(name: String) -> void:
	overlay_mode = true
	match name:
		"garage": _show_garage()
		"levels": _show_levels()
		"settings": _show_settings()
		_: _show_main()

func _show_main() -> void:
	if overlay_mode:
		quit_requested.emit()
		return
	_main_panel.visible = true
	_level_panel.visible = false
	_garage_panel.visible = false
	_settings_panel.visible = false
	_stats_label.text = "Levels: %d    Distance: %.1f km    Cars: %d" % [
		GameState.unlocked_level, GameState.total_distance / 1000.0, CarFactory.TOTAL_CARS]

func _show_levels() -> void:
	_main_panel.visible = false
	_level_panel.visible = true
	_garage_panel.visible = false
	_settings_panel.visible = false
	_refresh_levels()

func _show_garage() -> void:
	_main_panel.visible = false
	_level_panel.visible = false
	_garage_panel.visible = true
	_settings_panel.visible = false
	_garage_rebuild()

func _show_settings() -> void:
	_main_panel.visible = false
	_level_panel.visible = false
	_garage_panel.visible = false
	_settings_panel.visible = true

func _refresh_levels() -> void:
	for c in _level_grid.get_children():
		c.queue_free()
	for i in range(1, GameState.unlocked_level + 1):
		var lvl := i
		var s: int = GameState.get_stars(lvl)
		var b := _button("%d\n%s" % [lvl, "*".repeat(s)], 24)
		b.custom_minimum_size = Vector2(190, 130)
		b.pressed.connect(func(): start_level.emit(lvl, GameState.selected_car))
		_level_grid.add_child(b)
	var hint := _label("Beat Level %d to unlock Level %d" % [GameState.unlocked_level, GameState.unlocked_level + 1],
		20, Color(0.7, 0.78, 0.88))
	_level_grid.add_child(hint)

# ---------------------------------------------------------------- garage

func _garage_unlocked(idx: int) -> bool:
	return idx < 10 + GameState.unlocked_level * 5

func _garage_rebuild() -> void:
	var idx: int = GameState.selected_car
	for c in _car_pivot.get_children():
		c.queue_free()
	var data: Dictionary = CarFactory.build_car(idx)
	var body: Node3D = data["body"]
	_car_pivot.add_child(body)
	body.rotation.y = 0.35
	var st: Dictionary = data["stats"]
	_preview_label.text = CarFactory.car_name(idx)
	if _garage_unlocked(idx):
		_lock_label.text = "UNLOCKED"
		_lock_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	else:
		_lock_label.text = "LOCKED - reach a higher level"
		_lock_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
	_bar_speed.value = clampf(float(st["top_speed_kmh"]) / 340.0 * 100.0, 0.0, 100.0)
	_bar_accel.value = clampf(float(st["perf"]) * 100.0, 0.0, 100.0)
	_bar_handling.value = clampf((float(st["handling"]) - 0.9) / 0.35 * 100.0, 5.0, 100.0)

func _garage_step(dir: int) -> void:
	GameState.selected_car = posmod(GameState.selected_car + dir, CarFactory.TOTAL_CARS)
	_garage_rebuild()

func _garage_select() -> void:
	if _garage_unlocked(GameState.selected_car):
		GameState.save_game()
		_lock_label.text = "SELECTED"
		_lock_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))

func _garage_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_car_pivot.rotation.y += event.relative.x * 0.01
		_dragging = true
	elif event is InputEventScreenTouch:
		if not event.pressed:
			_dragging = false
	elif event is InputEventMouseButton:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_car_pivot.rotation.y += event.relative.x * 0.01

func _process(delta: float) -> void:
	if _garage_panel != null and _garage_panel.visible and _car_pivot != null and not _dragging:
		_car_pivot.rotation.y += _spin * delta
