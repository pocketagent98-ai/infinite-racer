class_name Minimap
extends Control
## Rotating minimap centred on the player: the player's heading points up and
## the track scrolls beneath.

const VIEW_RADIUS := 230.0

var track_pts: Array[Vector2] = []
var has_track: bool = false
var _player := Vector2.ZERO
var _fwd := Vector2(0, -1)
var _start := Vector2.ZERO
var _ai: Array[Vector2] = []

func set_track(curve: Curve3D) -> void:
	var pts: PackedVector3Array = curve.get_baked_points()
	track_pts.clear()
	for p in pts:
		track_pts.append(Vector2(p.x, p.z))
	has_track = not track_pts.is_empty()
	if has_track:
		_start = track_pts[0]

func update_racers(player_world: Vector3, ai_worlds: Array, forward: Vector2) -> void:
	_player = Vector2(player_world.x, player_world.z)
	if forward.length() > 0.01:
		_fwd = forward.normalized()
	_ai.clear()
	for w in ai_worlds:
		_ai.append(Vector2(w.x, w.z))
	queue_redraw()

func _map(v: Vector2) -> Vector2:
	var pad := 12.0
	var radius := minf(size.x, size.y) * 0.5 - pad
	var scale := radius / VIEW_RADIUS
	var rel := (v - _player) * scale
	var ang := -PI * 0.5 - atan2(_fwd.y, _fwd.x)
	var ca := cos(ang)
	var sa := sin(ang)
	var rot := Vector2(rel.x * ca - rel.y * sa, rel.x * sa + rel.y * ca)
	return Vector2(size.x * 0.5, size.y * 0.5) + rot

func _draw() -> void:
	var centre := Vector2(size.x * 0.5, size.y * 0.5)
	var radius := minf(size.x, size.y) * 0.5 - 12.0
	draw_circle(centre, radius + 8.0, Color(0, 0, 0, 0.4))
	draw_circle(centre, radius, Color(0.06, 0.09, 0.13, 0.75))
	if not has_track:
		return
	var n := track_pts.size()
	for i in range(n):
		var a := _map(track_pts[i])
		var b := _map(track_pts[(i + 1) % n])
		if a.distance_to(centre) < radius + 40.0 or b.distance_to(centre) < radius + 40.0:
			draw_line(a, b, Color(1, 1, 1, 0.8), 4.0, true)
	draw_circle(_map(_start), 5.0, Color(0.3, 1.0, 0.4))
	for p in _ai:
		draw_circle(_map(p), 4.0, Color(1.0, 0.75, 0.2))
	var tip := centre + Vector2(0, -8)
	var l := centre + Vector2(-5, 6)
	var r := centre + Vector2(5, 6)
	draw_colored_polygon(PackedVector2Array([tip, l, r]), Color(1.0, 0.25, 0.18))
