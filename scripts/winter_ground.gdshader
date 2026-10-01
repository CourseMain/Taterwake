shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

uniform vec4 snow_color : source_color = vec4(0.9412,0.9451,0.9412,1.0);
uniform vec4 shadow_color : source_color = vec4(0.77,0.85,0.90,1.0);
uniform bool ground_surface = true;
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
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}

void light() {
	// One white band and one pale-blue band. Actual shadow attenuation joins
	// the shaded band; light energy does not turn clean snow into grey mud.
	float lit = step(0.35, dot(NORMAL, LIGHT) * ATTENUATION);
	float strength = clamp(max(LIGHT_COLOR.r, max(LIGHT_COLOR.g, LIGHT_COLOR.b)) * 3.0, 0.0, 1.0);
	DIFFUSE_LIGHT += mix(shadow_color.rgb, snow_color.rgb, lit) * strength;
}
