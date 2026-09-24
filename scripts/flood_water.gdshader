shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float weather_time = 0.0;
uniform vec3 walker = vec3(1000.0);
varying vec4 bed;
varying vec3 world_pos;
void vertex() {
	bed = INSTANCE_CUSTOM;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wake = exp(-distance(world_pos.xz, walker.xz) * 0.7);
	VERTEX.y += sin(weather_time * 3.2 + world_pos.x * 2.5) * 0.027 + cos(weather_time * 4.1 + world_pos.z * 2.8) * 0.024;
	VERTEX.y += sin(distance(world_pos.xz, walker.xz) * 9.0 - weather_time * 8.0) * wake * 0.075;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	float edge = length(p) + sin(angle * 5.0 + weather_time * 2.0 + bed.y * 8.0) * 0.045 + cos(angle * 3.0 - weather_time * 2.7) * 0.035;
	float radius = 0.65 + bed.x * 0.34;
	float shoreline = 1.0 - smoothstep(radius - 0.045, radius, edge);
	float foam = smoothstep(radius - 0.14, radius - 0.075, edge);
	float ripple = pow(0.5 + 0.5 * sin(length(p + vec2(0.23, 0.16)) * 32.0 - weather_time * 4.0 + bed.y * 19.0), 14.0);
	float wake = exp(-distance(world_pos.xz, walker.xz) * 0.9) * pow(0.5 + 0.5 * sin(distance(world_pos.xz, walker.xz) * 12.0 - weather_time * 8.0), 6.0);
	vec3 water = mix(vec3(0.10, 0.40, 0.49), vec3(0.25, 0.71, 0.76), UV.y);
	ALBEDO = mix(water, vec3(0.75, 0.95, 0.88), clamp(foam * 0.7 + ripple * 0.26 + wake * 0.3, 0.0, 0.85));
	ALPHA = shoreline * (0.75 + bed.x * 0.15);
}
