shader_type spatial;
render_mode diffuse_burley;

uniform bool farm = false;
uniform vec4 grass_color : source_color = vec4(0.55, 0.67, 0.41, 1.0);
uniform bool snow = false;
uniform float snow_cover = 1.0;
uniform vec4 exposed_ground : source_color = vec4(0.6, 0.65, 0.4, 1.0);
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
	if (farm) {
		float high = smoothstep(0.25, 1.05, terrain_position.y);
		float wet = smoothstep(7.0,10.0,p.x) * smoothstep(7.0,10.0,p.y);
		vec3 grass = grass_color.rgb * (1.0 + (broad-0.5)*0.065 + (detail-0.5)*0.018);
		grass = mix(grass, grass * vec3(1.10,1.04,0.98), high*0.6);
		grass = mix(grass, grass * vec3(0.94,1.03,0.96), wet*0.6);
		vec3 strata = mix(pow(vec3(0.54,0.388,0.275),vec3(2.2)),pow(vec3(0.714,0.545,0.349),vec3(2.2)),smoothstep(-0.9,-0.55,terrain_position.y));
		ALBEDO = terrain_position.y > -0.25 ? grass : strata;
		ROUGHNESS = 0.95;
		SPECULAR = 0.12;
	} else if (snow) {
		float swept = sin(p.y * 1.4 + p.x * 0.24 + broad * 3.0) * 0.5 + 0.5;
		vec3 powder = mix(vec3(0.70, 0.755, 0.80), vec3(0.88, 0.90, 0.915), broad * 0.82 + 0.12);
		powder += (detail - 0.5) * 0.016 + grain * 0.013;
		powder -= vec3(0.03, 0.018, 0.008) * swept * 0.35;
		ALBEDO = pow(mix(vec3(0.74, 0.83, 0.89), powder, upper_surface), vec3(2.2));
		ROUGHNESS = 0.93;
		SPECULAR = 0.16;
	}
	if (snow) ALBEDO = mix(exposed_ground.rgb, ALBEDO, snow_cover);
}
