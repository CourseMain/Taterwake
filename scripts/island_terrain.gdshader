shader_type spatial;
render_mode diffuse_burley;

uniform vec4 grass_color : source_color = vec4(0.412, 0.624, 0.380, 1.0);
uniform vec4 grass_low : source_color = vec4(.2,.3,.14,1.);
varying vec3 terrain_position;
varying float occlusion;
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
	occlusion = COLOR.r;
	upper_surface = step(0.5, NORMAL.y);
}

void fragment() {
	vec2 p = terrain_position.xz;
	float broad = soft_noise(p * 0.23);
	float detail = soft_noise(p * 1.9);
	float high = smoothstep(0.8, 2.4, terrain_position.y);
	float wet = smoothstep(7.0,10.0,p.x) * smoothstep(7.0,10.0,p.y);
	vec3 grass = grass_color.rgb * (1.0 + (broad-0.5)*0.065 + (detail-0.5)*0.018);
	grass = mix(grass, grass * vec3(1.05,1.02,1.0), high*0.6);
	grass = mix(grass, grass * vec3(0.94,1.03,0.96), wet*0.6);
	// The grassy riser faces stay in the same palette, with readable relief.
	grass = mix(grass_low.rgb, grass, upper_surface);
	grass = mix(grass_low.rgb, grass, clamp((occlusion-.8)/.2,0.,1.));
	grass *= occlusion;
	// Faint far-side haze belongs to the terrain, without a screen-space pass.
	grass = mix(grass, vec3(.45,.52,.55), (1.-smoothstep(-27.,-10.,p.y))*.045);
	vec3 strata = mix(pow(vec3(0.54,0.388,0.275),vec3(2.2)),pow(vec3(0.714,0.545,0.349),vec3(2.2)),smoothstep(-0.9,-0.55,terrain_position.y));
	ALBEDO = terrain_position.y > -0.25 ? grass : strata;
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
}
