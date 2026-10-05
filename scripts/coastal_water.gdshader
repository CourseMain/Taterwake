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
uniform vec2 sun_screen = vec2(.65,.1);
uniform vec3 sun_direction = vec3(0.,.5,-.86);
uniform vec3 sun_colour : source_color = vec3(1.,.94,.8);
uniform vec3 sky_top : source_color = vec3(.4,.6,.7);
uniform vec3 camera_world = vec3(14.,35.,43.);
uniform float sun_visibility = 1.0;
uniform float view_aspect = 1.6;
varying vec2 sea_pos;
void vertex() {
	sea_pos = VERTEX.xz;
	if (!title_mode) {
		VERTEX.y += sin(VERTEX.x * 0.12 + water_clock * 0.32) * 0.022 + cos(VERTEX.z * 0.10 - water_clock * 0.25) * 0.018;
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
		// Five broad, feathered pools. Their bounded screen count remains calm
		// at every zoom; each drifts over a sixteen-second cycle.
		vec2 drift = vec2(sin(water_clock * .39),cos(water_clock * .31)) * .018;
		float glow = title_highlight(SCREEN_UV,vec2(.12,.24)+drift,vec2(.17,.022));
		glow += title_highlight(SCREEN_UV,vec2(.76,.18)-drift,vec2(.15,.017));
		glow += title_highlight(SCREEN_UV,vec2(.91,.51)+drift,vec2(.18,.024));
		glow += title_highlight(SCREEN_UV,vec2(.16,.70)-drift,vec2(.20,.025));
		glow += title_highlight(SCREEN_UV,vec2(.65,.87)+drift,vec2(.19,.019));
		float foam = (1.-smoothstep(.10,.22,abs(shore-.35))) * (.20+.08*sin(water_clock*.35));
		water = mix(water,foam_color,foam+glow*.17);
		water *= mix(vec3(.92,.97,1.05),vec3(1.06,1.02,.94),(1.-smoothstep(.1,.8,SCREEN_UV.x)));
	}
	// Ocean covers the complete camera view, including the far distance.
	// A subtle sky tint follows dusk without dissolving the sea into a void.
	vec3 result = mix(water * mix(0.45, 1.0, daylight), horizon_color, 0.09);
	if (!title_mode) {
		// Orthographic rays all have the same sky direction and the far sea
		// covers the skybox. Draw its horizon here, behind all farm geometry.
		vec2 sun_delta = (SCREEN_UV-sun_screen)*vec2(view_aspect,1.);
		float radius = length(sun_delta);
		float disc = 1.-smoothstep(.014,.019,radius);
		float halo = exp(-radius*radius*900.)*.35;
		float warmth = exp(-radius*radius*9.)*.22*sun_visibility;
		vec3 sky = mix(horizon_color,sky_top,1.-smoothstep(.0,.22,SCREEN_UV.y));
		sky = mix(sky,sun_colour,warmth);
		sky = mix(sky,sun_colour,clamp((disc+halo)*sun_visibility,0.,1.));
		float haze = exp(-pow((SCREEN_UV.y-.22)*35.,2.))*.17;
		result = mix(result,horizon_color,haze);
		result = mix(result,sky,1.-smoothstep(.19,.29,SCREEN_UV.y));
		// Direct sun reflection uses the same light direction as the island.
		vec3 normal = normalize(vec3(sin(sea_pos.x*.19+water_clock*.4)*.09,1.,cos(sea_pos.y*.23-water_clock*.3)*.07));
		vec3 view = normalize(camera_world-vec3(sea_pos.x,0.,sea_pos.y));
		float glint = pow(max(0.,dot(reflect(-sun_direction,normal),view)),90.);
		result += sun_colour*glint*.3*sun_visibility*smoothstep(.29,.38,SCREEN_UV.y);
	}
	ALBEDO = result;
}
