shader_type spatial;
render_mode specular_disabled;

uniform vec4 snow_color : source_color = vec4(0.9412,0.9451,0.9412,1.0);
uniform vec4 shadow_color : source_color = vec4(0.788235,0.850980,0.890196,1.0);
uniform bool ground_surface = true;
uniform bool single_light_pass = false;
uniform float pillow_height = 0.035;

void vertex() {
	if (ground_surface) {
		float x = VERTEX.x * 0.65;
		float z = VERTEX.z * 0.52;
		VERTEX.y += pillow_height * (0.5 + 0.5 * sin(x) * cos(z));
		NORMAL = normalize(NORMAL + vec3(-pillow_height * 0.325 * cos(x) * cos(z), 0.0, pillow_height * 0.26 * sin(x) * sin(z)));
	}
}

void fragment() {
	ALBEDO = snow_color.rgb;
	// Keep ambient fill below clipping in the Compatibility additive pass.
	AO = 0.12;
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}

void light() {
	// Use Godot's lit surface path: real normals, radiance and shadow-map
	// attenuation drive the two bands; the environment supplies ambient fill.
	float normal_band = step(0.35, dot(NORMAL, LIGHT));
	float lit = normal_band * ATTENUATION;
	vec3 shade = shadow_color.rgb / max(snow_color.rgb, vec3(0.001));
	DIFFUSE_LIGHT += mix(shade * 0.86, vec3(1.3), lit) * LIGHT_COLOR * 0.90 / PI * (single_light_pass ? 1.9 : 1.0);
}
