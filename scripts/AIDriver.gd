class_name AIDriver
extends Node3D
## Opponent car: follows the track centre line at a target speed with a
## per-car lateral offset. Kinematic, so racing stays stable and cheap.

var curve: Curve3D
var length: float = 1.0
var dist: float = 0.0
var target_speed: float = 30.0
var lane_offset: float = 0.0
var laps: int = 0
var body: Node3D
var finished: bool = false

func configure(car_index: int, c: Curve3D, start_dist: float, spd: float, lane: float) -> void:
	var data: Dictionary = CarFactory.build_car(car_index)
	body = data.body
	add_child(body)
	curve = c
	length = max(1.0, c.get_baked_length())
	dist = fmod(start_dist, length)
	target_speed = spd
	lane_offset = lane
	_apply()

func _physics_process(delta: float) -> void:
	if finished:
		return
	var speed: float = target_speed * _corner_factor()
	dist += speed * delta
	if dist >= length:
		dist = fmod(dist, length)
		laps += 1
	_apply()

func _corner_factor() -> float:
	var a: Vector3 = curve.sample_baked_with_rotation(dist, true, false).basis.z
	var b: Vector3 = curve.sample_baked_with_rotation(fmod(dist + 12.0, length), true, false).basis.z
	var d: float = clampf(a.dot(b), -1.0, 1.0)
	var turn: float = acos(d)
	return clampf(1.0 - turn * 1.6, 0.55, 1.0)

func _apply() -> void:
	var t: Transform3D = curve.sample_baked_with_rotation(dist, true, false)
	# rotate 180 deg so the car's +Z faces along the racing line
	var basis: Basis = t.basis.rotated(Vector3.UP, PI)
	var right: Vector3 = basis.x
	var pos: Vector3 = t.origin + right * lane_offset + Vector3.UP * 0.55
	global_transform = Transform3D(basis, pos)

func progress() -> float:
	return float(laps) * length + dist
