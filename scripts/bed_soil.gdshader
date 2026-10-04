shader_type spatial;
uniform vec4 soil_color : source_color = vec4(.46,.33,.22,1.);
void fragment() {
	float edge = max(abs(UV.x-.5),abs(UV.y-.5));
	float rim = smoothstep(.44,.49,edge)*.025;
	float inset = (1.-smoothstep(.40,.48,edge))*smoothstep(.28,.40,edge)*.12;
	ALBEDO = soil_color.rgb*(1.-rim-inset);
	ROUGHNESS = .96;
	SPECULAR = .08;
}
