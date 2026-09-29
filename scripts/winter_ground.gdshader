shader_type spatial;
render_mode diffuse_burley;

uniform float exposure_threshold = 0.35;
uniform vec4 snow_color : source_color = vec4(0.9412,0.9451,0.9412,1.0);
varying float snow_mask;

void vertex() {
	snow_mask = COLOR.r;
}

void fragment() {
	// Opaque cutouts reveal the real grass, rather than painting green spots
	// over snow. The low Winter light supplies the faint blue in its shadows.
	if (snow_mask < exposure_threshold) { discard; }
	ALBEDO = snow_color.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}
