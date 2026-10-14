class_name Splash
extends CanvasLayer
## Intro: a studio logo on a purple gradient, then a loading screen with a
## REAL progress percentage (it preloads the car models on a worker thread).

signal finished

var _root: Control
var _logo_layer: Control
var _load_layer: Control
var _bar: ProgressBar
var _pct: Label
var _paths: Array[String] = []
var _idx: int = 0

func _ready() -> void:
	layer = 60
	_build_logo()
	_build_loading()

func _label(text: String, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _gradient() -> ColorRect:
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.color = Color(0.18, 0.06, 0.34)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cr

# ---------------------------------------------------------------- studio logo

func _build_logo() -> void:
	_logo_layer = Control.new()
	_logo_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_logo_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo_layer)

	var bg := _gradient()
	bg.color = Color(0.16, 0.05, 0.32)
	_logo_layer.add_child(bg)
	# a second band to fake a gradient
	var band := ColorRect.new()
	band.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	band.custom_minimum_size = Vector2(720, 640)
	band.color = Color(0.32, 0.10, 0.55)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_layer.add_child(band)

	var name := _label("SARVAM", 74, Color(1, 1, 1))
	name.set_anchors_preset(Control.PRESET_CENTER)
	name.position = Vector2(-360, -110)
	name.custom_minimum_size = Vector2(720, 100)
	name.modulate.a = 0.0
	_logo_layer.add_child(name)

	var sub := _label("STUDIO", 30, Color(0.85, 0.75, 1.0))
	sub.set_anchors_preset(Control.PRESET_CENTER)
	sub.position = Vector2(-360, 0)
	sub.custom_minimum_size = Vector2(720, 44)
	sub.modulate.a = 0.0
	_logo_layer.add_child(sub)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(name, "modulate:a", 1.0, 0.8)
	tw.tween_property(name, "position:y", -110.0, 0.8).from(-70.0)
	tw.tween_property(sub, "modulate:a", 1.0, 0.8).set_delay(0.25)
	var tw2 := create_tween()
	tw2.tween_interval(1.6)
	tw2.tween_property(_logo_layer, "modulate:a", 0.0, 0.4)
	tw2.tween_callback(_play_loading)

# ---------------------------------------------------------------- loading

func _build_loading() -> void:
	_load_layer = Control.new()
	_load_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_layer.visible = false
	_load_layer.modulate.a = 0.0
	add_child(_load_layer)

	_load_layer.add_child(_gradient())

	var title := _label("INFINITE RACER", 54, Color(1, 0.85, 0.3))
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-360, -120)
	title.custom_minimum_size = Vector2(720, 80)
	_load_layer.add_child(title)

	var hint := _label("loading cars and tracks", 20, Color(0.8, 0.85, 0.95))
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.position = Vector2(-360, -40)
	hint.custom_minimum_size = Vector2(720, 30)
	_load_layer.add_child(hint)

	_bar = ProgressBar.new()
	_bar.set_anchors_preset(Control.PRESET_CENTER)
	_bar.position = Vector2(-260, 40)
	_bar.custom_minimum_size = Vector2(520, 26)
	_bar.size = Vector2(520, 26)
	_bar.max_value = 100.0
	_bar.value = 0.0
	_bar.show_percentage = false
	_load_layer.add_child(_bar)

	_pct = _label("0%", 26, Color.WHITE)
	_pct.set_anchors_preset(Control.PRESET_CENTER)
	_pct.position = Vector2(-360, 86)
	_pct.custom_minimum_size = Vector2(720, 34)
	_load_layer.add_child(_pct)

func _play_loading() -> void:
	_load_layer.visible = true
	var tw := create_tween()
	tw.tween_property(_load_layer, "modulate:a", 1.0, 0.4)
	# queue every car model for threaded loading -> real progress
	_paths.clear()
	for i in range(CarFactory.TOTAL_CARS):
		var p: String = "res://assets/cars/%s.glb" % String(CarFactory.CAR_MODELS[i % CarFactory.CAR_MODELS.size()]["f"])
		if not _paths.has(p):
			_paths.append(p)
	for p in _paths:
		ResourceLoader.load_threaded_request(p)
	set_process(true)

func _process(_delta: float) -> void:
	if not _load_layer.visible:
		return
	if _idx < _paths.size():
		var p: String = _paths[_idx]
		var st: int = ResourceLoader.load_threaded_get_status(p)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(p)
			_idx += 1
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_idx += 1
	else:
		_idx += 1   # one extra tick to show 100%
	var total: float = float(_paths.size() + 1)
	var pct: float = clampf(float(_idx) / maxf(1.0, total) * 100.0, 0.0, 100.0)
	_bar.value = pct
	_pct.text = "Loading... %d%%" % int(pct)
	if _idx > _paths.size():
		set_process(false)
		var tw := create_tween()
		tw.tween_property(_load_layer, "modulate:a", 0.0, 0.4)
		tw.tween_callback(func(): finished.emit())
