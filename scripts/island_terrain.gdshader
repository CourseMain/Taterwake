shader_type spatial;
render_mode diffuse_burley;

uniform bool snow = false;
uniform float snow_cover = 1.0;
uniform vec4 exposed_ground : source_color = vec4(0.6, 0.65, 0.4, 1.0);
uniform vec2 half_extent = vec2(23.15, 18.15);
varying vec3 terrain_position;
varying float upper_surface;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float soft_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	terrain_position = VERTEX;
	upper_surface = step(0.5, NORMAL.y);
}

void fragment() {
	vec2 p = terrain_position.xz;
	float broad = soft_noise(p * 0.23);
	float detail = soft_noise(p * 1.9);
	// Filtering keeps fine grains from sparkling or crawling when zoomed out.
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float grain_fade = 1.0 - smoothstep(0.025, 0.15, footprint);
	float grain = (soft_noise(p * 32.0) - 0.5) * grain_fade;
	if (snow) {
		float swept = sin(p.y * 1.4 + p.x * 0.24 + broad * 3.0) * 0.5 + 0.5;
		vec3 powder = mix(vec3(0.70, 0.755, 0.80), vec3(0.88, 0.90, 0.915), broad * 0.82 + 0.12);
		powder += (detail - 0.5) * 0.016 + grain * 0.013;
		powder -= vec3(0.03, 0.018, 0.008) * swept * 0.35;
		ALBEDO = pow(mix(vec3(0.74, 0.83, 0.89), powder, upper_surface), vec3(2.2));
		ROUGHNESS = 0.93;
		SPECULAR = 0.16;
	} else {
		vec2 edge = half_extent - abs(p);
		float shore_distance = min(min(edge.x, edge.y), (edge.x + edge.y - 2.3) * 0.7071);
		float dry = smoothstep(-0.6, 1.7 + broad * 1.4, shore_distance);
		float ripple = sin(p.y * 7.4 + p.x * 1.1 + broad * 8.0 + detail * 1.4);
		float ripple_fade = 1.0 - smoothstep(0.14, 0.48, footprint);
		vec3 sand = mix(vec3(0.72, 0.695, 0.63), vec3(0.84, 0.825, 0.755), dry);
		sand += (broad - 0.5) * vec3(0.055, 0.05, 0.04);
		sand += (detail - 0.5) * 0.026 + grain * 0.055;
		sand += ripple * ripple_fade * 0.007 * smoothstep(0.28, 0.68, broad);
		ALBEDO = pow(mix(vec3(0.72, 0.695, 0.63), sand, upper_surface), vec3(2.2));
		ROUGHNESS = mix(0.72, 0.98, dry);
		SPECULAR = 0.12;
	}
	if (snow) ALBEDO = mix(exposed_ground.rgb, ALBEDO, snow_cover);
}
