shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// One opaque coastal ring; no depth/screen textures, transparency or reflections.
uniform float water_clock = 0.0;
uniform bool title_mode = false;
// Normalized clip depth, independent of the island's shadow camera slice.
uniform float sea_clip_depth = -0.9999;
uniform vec3 shallow_color : source_color = vec3(0.36, 0.72, 0.65);
uniform vec3 deep_color : source_color = vec3(0.19, 0.49, 0.56);
uniform vec3 foam_color : source_color = vec3(0.84, 0.94, 0.80);
uniform vec3 horizon_color : source_color = vec3(0.73, 0.84, 0.79);
uniform float daylight = 1.0;
varying vec2 sea_pos;
void vertex() {
	sea_pos = VERTEX.xz;
	if (!title_mode) {
		VERTEX.y += sin(VERTEX.x * 0.55 + water_clock * 1.1) * 0.022 + cos(VERTEX.z * 0.65 - water_clock * 0.8) * 0.018;
	}
	// The island camera uses a tight depth slice for detailed orthogonal shadows.
	// Preserve the sea's screen shape but keep its non-shadow-casting surface
	// behind the island in Compatibility's reverse-Z clip space (far is -1).
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z = sea_clip_depth * POSITION.w;
}
float title_highlight(vec2 point, vec2 center, vec2 span) {
	return 1.0 - smoothstep(0.2, 1.0, length((point - center) / span));
}
void fragment() {
	float shore = UV.x;
	vec3 water = mix(shallow_color, deep_color, smoothstep(0.0, 9.0, shore));
	if (title_mode) {
		// The orthographic sea fills the horizon: reflect the welcome's warm
		// sky across the upper view while keeping the foreground cool and quiet.
		float horizon_glow = 1.0 - smoothstep(0.0, 0.70, SCREEN_UV.y);
		water = mix(water, horizon_color, horizon_glow * 0.85);
		// Three quiet pools of dusk light, never a repeating wave texture.
		// Screen coordinates keep their count bounded during the title pan.
		vec2 drift = vec2(sin(water_clock * 0.07), cos(water_clock * 0.045)) * 0.007;
		float glow = title_highlight(SCREEN_UV, vec2(0.17, 0.35) + drift, vec2(0.12, 0.008));
		glow += title_highlight(SCREEN_UV, vec2(0.82, 0.56) - drift, vec2(0.10, 0.006));
		glow += title_highlight(SCREEN_UV, vec2(0.31, 0.81) + drift * 0.7, vec2(0.15, 0.007));
		water = mix(water, foam_color, glow * 0.13);
	} else {
		// Broad curling ribbons and smaller crossing ripples. Six trigonometric
		// evaluations, one opaque pass, no reflections or screen/depth reads.
		float bend = sin(sea_pos.y * 0.30 + water_clock * 0.18) + cos(sea_pos.x * 0.22 - sea_pos.y * 0.10) * 0.45;
		float ribbon = sin(sea_pos.x * 0.46 + sea_pos.y * 0.25 + bend * 2.2 - water_clock * 0.55);
		float chop = sin(sea_pos.y * 0.9 - sea_pos.x * 0.3 + water_clock * 0.48);
		float breaker = sin(shore * 3.0 - water_clock * 1.2 + bend);
		float breaks = smoothstep(-0.3, 0.7, sin(UV.y * 0.65 + water_clock * 0.15));
		float foam = smoothstep(0.86, 0.99, breaker) * breaks * (1.0 - smoothstep(0.8, 4.2, shore));
		float crest = smoothstep(0.975, 0.996, ribbon) * smoothstep(-0.15, 0.6, chop);
		water += (ribbon * 0.014 + chop * 0.008);
		water = mix(water, foam_color, foam * 0.65 + crest * 0.36);
	}
	// Ocean covers the complete camera view, including the far distance.
	// A subtle sky tint follows dusk without dissolving the sea into a void.
	ALBEDO = mix(water * mix(0.45, 1.0, daylight), horizon_color, 0.09);
}
