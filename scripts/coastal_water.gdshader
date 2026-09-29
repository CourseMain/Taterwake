shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// One opaque coastal ring; no depth/screen textures, transparency or reflections.
uniform float water_clock = 0.0;
uniform vec3 shallow_color : source_color = vec3(0.36, 0.72, 0.65);
uniform vec3 deep_color : source_color = vec3(0.19, 0.49, 0.56);
uniform vec3 foam_color : source_color = vec3(0.84, 0.94, 0.80);
uniform vec3 horizon_color : source_color = vec3(0.73, 0.84, 0.79);
uniform float daylight = 1.0;
varying vec2 sea_pos;
void vertex() {
	sea_pos = VERTEX.xz;
	VERTEX.y += sin(VERTEX.x * 0.55 + water_clock * 1.1) * 0.022 + cos(VERTEX.z * 0.65 - water_clock * 0.8) * 0.018;
}
void fragment() {
	float shore = UV.x;
	// Broad curling ribbons and smaller crossing ripples. Six trigonometric
	// evaluations, one opaque pass, no reflections or screen/depth reads.
	float bend = sin(sea_pos.y * 0.30 + water_clock * 0.18) + cos(sea_pos.x * 0.22 - sea_pos.y * 0.10) * 0.45;
	float ribbon = sin(sea_pos.x * 0.46 + sea_pos.y * 0.25 + bend * 2.2 - water_clock * 0.55);
	float chop = sin(sea_pos.y * 0.9 - sea_pos.x * 0.3 + water_clock * 0.48);
	float breaker = sin(shore * 3.0 - water_clock * 1.2 + bend);
	float breaks = smoothstep(-0.3, 0.7, sin(UV.y * 0.65 + water_clock * 0.15));
	float foam = smoothstep(0.86, 0.99, breaker) * breaks * (1.0 - smoothstep(0.8, 4.2, shore));
	float crest = smoothstep(0.975, 0.996, ribbon) * smoothstep(-0.15, 0.6, chop);
	vec3 water = mix(shallow_color, deep_color, smoothstep(0.0, 9.0, shore));
	water += (ribbon * 0.014 + chop * 0.008);
	water = mix(water, foam_color, foam * 0.65 + crest * 0.36);
	// Ocean covers the complete camera view, including the far distance.
	// A subtle sky tint follows dusk without dissolving the sea into a void.
	ALBEDO = mix(water * mix(0.45, 1.0, daylight), horizon_color, 0.09);
}
