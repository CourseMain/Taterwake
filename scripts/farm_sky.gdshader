shader_type sky;
uniform vec3 top_color : source_color = vec3(.30,.46,.58);
uniform vec3 horizon_color : source_color = vec3(.75,.83,.86);
uniform vec3 sun_direction = vec3(0.,.5,-.86);
uniform vec3 sun_colour : source_color = vec3(1.,.94,.80);
uniform float sun_visibility = 1.0;
void sky() {
	float height = clamp(EYEDIR.y,0.,1.);
	float towards = max(0.,dot(normalize(EYEDIR),sun_direction));
	vec3 sky_colour = mix(horizon_color,top_color,pow(height,.4));
	sky_colour = mix(sky_colour,sun_colour,pow(towards,8.)*.20*sun_visibility);
	sky_colour = mix(sky_colour,horizon_color,exp(-height*height*180.)*.15);
	float halo = pow(towards,140.)*.28;
	float disc = smoothstep(.99945,.9998,towards);
	COLOR = mix(sky_colour,sun_colour,clamp((halo+disc)*sun_visibility,0.,1.));
}
