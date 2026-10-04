shader_type sky;
uniform vec3 top_color : source_color = vec3(.30,.46,.58);
uniform vec3 horizon_color : source_color = vec3(.75,.83,.86);
void sky() {
	COLOR = mix(horizon_color,top_color,pow(clamp(EYEDIR.y,0.,1.),.4));
}
