shader_type canvas_item;
render_mode unshaded;
uniform float clock_time = 0.0;
uniform float altitude = 0.0;
uniform float ignition = 0.0;
uniform float aspect = 1.6;
uniform vec4 accent : source_color = vec4(0.29, 0.92, 0.78, 1.0);
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
void fragment() {
	vec2 uv = UV;
	vec2 p = vec2((uv.x - 0.5) * aspect, uv.y);
	vec3 sky = mix(vec3(0.016, 0.027, 0.090), vec3(0.044, 0.109, 0.180), pow(uv.y, 1.5));
	float cloud = sin(p.x * 3.0 + uv.y * 4.0) * sin(p.x * 5.0 - uv.y * 3.2 + 1.0);
	sky += vec3(0.028, 0.017, 0.058) * (cloud + 1.0) * 0.45;
	for (int i = 0; i < 3; i++) {
		float layer = float(i);
		vec2 sp = vec2(p.x, uv.y + altitude * (0.00002 + layer * 0.000015));
		float grid = 37.0 + layer * 21.0;
		vec2 cell = floor(sp * grid);
		vec2 local = fract(sp * grid) - 0.5;
		float h = hash21(cell + layer * 113.0);
		vec2 offset = vec2(hash21(cell + 11.7), hash21(cell + 29.9)) * 0.6 - 0.3;
		float radius = 0.024 + h * 0.035;
		float star = (1.0 - smoothstep(radius * 0.18, radius, length(local - offset))) * step(0.865, h);
		float twinkle = 0.64 + 0.36 * sin(clock_time * (0.7 + h) + h * 84.0);
		sky += mix(vec3(0.55, 0.75, 1.0), vec3(1.0, 0.84, 0.60), h) * star * twinkle * (1.0 - layer * 0.17);
	}
	for (int i = 0; i < 3; i++) {
		float f = float(i);
		float bend = 0.23 + sin(p.x * 2.8 + f * 0.5 + clock_time * 0.055) * 0.095;
		bend += sin(p.x * 6.7 - clock_time * 0.10 + f * 0.35) * 0.024;
		float d = uv.y - bend - f * 0.036;
		float ribbon = exp(-abs(d) * (d > 0.0 ? 21.0 : 90.0));
		float curtain = 0.45 + 0.55 * pow(0.5 + 0.5 * sin(p.x * 95.0 + sin(p.x * 13.0 + clock_time * 0.14) * 4.0), 2.0);
		float edge = smoothstep(-0.9, -0.4, p.x) * (1.0 - smoothstep(0.5, 1.0, p.x));
		vec3 hue = mix(accent.rgb, vec3(0.43, 0.35, 0.95), f * 0.30);
		sky += hue * ribbon * curtain * edge * (0.13 - f * 0.022);
	}
	float launch_glow = exp(-length(vec2(p.x * 1.5, (uv.y - 0.80) * 1.0)) * 4.2);
	sky += vec3(0.52, 0.18, 0.045) * launch_glow * ignition * 0.65;
	float vignette = 1.0 - smoothstep(0.22, 1.06, length(vec2(p.x * 0.75, uv.y - 0.48)));
	sky *= 0.76 + 0.24 * vignette;
	COLOR = vec4(sky, 1.0);
}
