shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform float water_clock = 0.0;
uniform float daylight = 1.0;
varying float top_face;
void vertex() {
	top_face = NORMAL.y;
	float phase = INSTANCE_CUSTOM.x * 6.28318;
	VERTEX.y += sin(water_clock * 0.65 + phase) * 0.045;
	VERTEX.x += sin(water_clock * 0.16 + phase) * 0.11;
}
void fragment() {
	ALBEDO = mix(vec3(0.43, 0.72, 0.82), vec3(0.89, 0.96, 0.97), step(0.4, top_face)) * mix(0.65, 1.0, daylight);
}
