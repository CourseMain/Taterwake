shader_type spatial;
render_mode specular_disabled;

uniform vec4 snow_color : source_color = vec4(0.9412,0.9451,0.9412,1.0);
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
	// Ordinary diffuse lighting lets the same sun shade snow and grass.
	AO = 0.6;
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}
