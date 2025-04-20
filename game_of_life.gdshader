shader_type spatial;

uniform sampler2D cells: filter_nearest, repeat_disable;

void vertex() {
}

void fragment() {
	ALBEDO = vec3(texture(cells, UV).r);
}