extends Node
## Root controller: studio logo + loading, then straight into the start-line
## lobby (seamless pre-race). The Menu is reachable from the lobby / pause.

var current_screen: Node = null
var _fade_layer: CanvasLayer
var _fade: ColorRect
var _busy: bool = false

func _ready() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)

	var SplashScript: GDScript = load("res://scripts/Splash.gd")
	var splash: Node = SplashScript.new()
	add_child(splash)
	splash.finished.connect(func():
		if is_instance_valid(splash):
			splash.queue_free()
		start_race(GameState.unlocked_level, GameState.selected_car))

func _clear_screen() -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = null

func _transition(cb: Callable) -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.22)
	tw.tween_callback(cb)
	tw.tween_property(_fade, "color:a", 0.0, 0.26)
	tw.tween_callback(func(): _busy = false)

## Straight to the start line (no separate home screen).
func start_race(level: int, car_index: int) -> void:
	_transition(func():
		_clear_screen()
		var RaceScript: GDScript = load("res://scripts/RaceManager.gd")
		var race: Node = RaceScript.new()
		race.name = "RaceManager"
		race.level = level
		race.car_index = car_index
		add_child(race)
		race.exit_to_menu.connect(show_menu)
		race.next_level.connect(start_race)
		current_screen = race)

func show_menu() -> void:
	_transition(func():
		_clear_screen()
		var MenuScript: GDScript = load("res://scripts/Menu.gd")
		var menu: Node = MenuScript.new()
		menu.name = "Menu"
		add_child(menu)
		menu.start_level.connect(start_race)
		menu.quit_requested.connect(func(): get_tree().quit())
		current_screen = menu)
