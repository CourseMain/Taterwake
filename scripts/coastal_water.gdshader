shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// One opaque coastal ring; no depth/screen textures, transparency or reflections.
uniform float water_clock = 0.0;
uniform vec3 shallow_color : source_color = vec3(0.36, 0.72, 0.65);
uniform vec3 deep_color : source_color = vec3(0.19, 0.49, 0.56);
uniform vec3 foam_color : source_color = vec3(0.84, 0.94, 0.80);
uniform vec3 horizon_color : source_color = vec3(0.73, 0.84, 0.79);
uniform float daylight = 1.0;
uniform float icy = 0.0;
varying vec2 sea_pos;
void vertex() {
	sea_pos = VERTEX.xz;
	VERTEX.y += sin(VERTEX.x * 0.55 + water_clock * 1.1) * 0.022 + cos(VERTEX.z * 0.65 - water_clock * 0.8) * 0.018;
}
void fragment() {
	float shore = UV.x;
	float swell = sin(shore * 3.6 - water_clock * (1.3 - icy * 0.4) + sin(UV.y * 0.40) * 0.45);
	float breaks = smoothstep(-0.45, 0.55, sin(UV.y * 0.75 + water_clock * 0.22));
	float foam = smoothstep(0.88, 0.99, swell) * breaks * (1.0 - smoothstep(0.6, 4.1, shore));
	float ripple = sin(sea_pos.x * 1.55 + sea_pos.y * 0.80 + water_clock * 0.65);
	float glint = smoothstep(0.96, 1.0, ripple) * smoothstep(0.45, 0.95, sin(sea_pos.y * 2.1 - water_clock * 0.38));
	vec3 water = mix(shallow_color, deep_color, smoothstep(0.0, 7.0, shore));
	water = mix(water, foam_color, foam * 0.66 + glint * 0.12);
	water *= mix(0.50, 1.0, daylight);
	// Fade the opaque geometry into the diorama background at the far edge.
	ALBEDO = mix(water, horizon_color, smoothstep(8.0, 13.0, shore));
}
