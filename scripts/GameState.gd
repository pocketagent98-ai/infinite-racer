extends Node
## Global autoload: input map, player progress, settings, persistence.

const SAVE_PATH := "user://infinite_racer_save.json"
const TOTAL_CARS := 100

var unlocked_level: int = 1
var selected_car: int = 0
var best_times: Dictionary = {}
var stars: Dictionary = {}
var total_distance: float = 0.0

# settings
var quality: int = 2                 # 0 low, 1 medium, 2 high
var volume: float = 0.8
var shake_enabled: bool = true

# one-touch driving input, written by the HUD and read by the car
var touch_drive: bool = false
var touch_steer: float = 0.0

func _ready() -> void:
	_setup_input()
	load_game()

func _setup_input() -> void:
	_add_action("accelerate", [KEY_UP, KEY_W], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_action("brake", [KEY_DOWN, KEY_S], JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_action("steer_left", [KEY_LEFT, KEY_A], JOY_AXIS_LEFT_X, -1.0)
	_add_action("steer_right", [KEY_RIGHT, KEY_D], JOY_AXIS_LEFT_X, 1.0)
	_add_action("handbrake", [KEY_SPACE], JOY_BUTTON_A, 0.0)
	_add_action("nitro", [KEY_N, KEY_SHIFT], JOY_BUTTON_X, 0.0)
	_add_action("reset_car", [KEY_R], JOY_BUTTON_Y, 0.0)
	_add_action("pause", [KEY_ESCAPE], JOY_BUTTON_START, 0.0)
	_add_action("camera_change", [KEY_C], JOY_BUTTON_B, 0.0)

func _add_action(action: StringName, keys: Array, joy_axis: int = -1, axis_value: float = 0.0) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.35)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	if joy_axis >= 0:
		var je := InputEventJoypadMotion.new()
		je.axis = joy_axis
		je.axis_value = axis_value
		InputMap.action_add_event(action, je)

# ---------------------------------------------------------------- progress

func register_level_complete(level: int, time: float, earned_stars: int) -> void:
	var key := str(level)
	if not best_times.has(key) or time < float(best_times[key]):
		best_times[key] = time
	if not stars.has(key) or earned_stars > int(stars[key]):
		stars[key] = earned_stars
	if level + 1 > unlocked_level:
		unlocked_level = level + 1
	save_game()

func get_stars(level: int) -> int:
	return int(stars.get(str(level), 0))

func get_best_time(level: int) -> float:
	return float(best_times.get(str(level), 0.0))

func add_distance(m: float) -> void:
	total_distance += m

# ---------------------------------------------------------------- persistence

func save_game() -> void:
	var data := {
		"unlocked_level": unlocked_level,
		"selected_car": selected_car,
		"best_times": best_times,
		"stars": stars,
		"total_distance": total_distance,
		"quality": quality,
		"volume": volume,
		"shake_enabled": shake_enabled,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not open save file for writing.")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	unlocked_level = max(1, int(d.get("unlocked_level", 1)))
	selected_car = clampi(int(d.get("selected_car", 0)), 0, TOTAL_CARS - 1)
	best_times = d.get("best_times", {})
	stars = d.get("stars", {})
	total_distance = float(d.get("total_distance", 0.0))
	quality = clampi(int(d.get("quality", 2)), 0, 2)
	volume = clampf(float(d.get("volume", 0.8)), 0.0, 1.0)
	shake_enabled = bool(d.get("shake_enabled", true))

## Safe-area insets (notches / rounded corners) in the project base resolution.
func safe_insets() -> Vector4:
	var base := Vector2(1280, 720)
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return Vector4.ZERO
	var sa := DisplayServer.get_display_safe_area()
	var sx := base.x / float(win.x)
	var sy := base.y / float(win.y)
	return Vector4(
		float(sa.position.x) * sx,
		float(sa.position.y) * sy,
		float(win.x - sa.end.x) * sx,
		float(win.y - sa.end.y) * sy)

func reset_progress() -> void:
	unlocked_level = 1
	best_times = {}
	stars = {}
	total_distance = 0.0
	save_game()
