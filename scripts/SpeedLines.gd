class_name SpeedLines
extends Control
## Full-screen radial speed-line overlay. Intensity is driven by car speed,
## giving the "sense of speed" effect.

var intensity: float = 0.0
var _mat: ShaderMaterial

const SHADER := """
shader_type canvas_item;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform float density : hint_range(5.0, 80.0) = 46.0;
uniform float speed : hint_range(0.1, 10.0) = 4.0;
uniform float inner_radius : hint_range(0.0, 1.0) = 0.42;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
float rand2(vec2 uv) { return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123); }
void fragment() {
	vec2 o = UV - vec2(0.5, 0.5);
	float d = length(o);
	float ang = atan(o.y, o.x);
	float sector = floor((ang + 3.14159) / (2.0 * 3.14159) * density);
	float n = rand2(vec2(sector, floor(TIME * speed)));
	float mask = smoothstep(inner_radius, 1.0, d) * intensity;
	if (n > 0.62) { COLOR = vec4(line_color.rgb, line_color.a * mask); }
	else { COLOR = vec4(0.0); }
}
"""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	material = _mat
	set_intensity(0.0)

func set_intensity(v: float) -> void:
	intensity = clampf(v, 0.0, 1.0)
	if _mat != null:
		_mat.set_shader_parameter("intensity", intensity)
