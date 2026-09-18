shader_type canvas_item;
render_mode unshaded;
uniform vec4 aura_color : source_color = vec4(0.03, 1.0, 0.36, 1.0);
uniform float energy = 0.0;
uniform float clock_time = 0.0;
uniform float jackpot = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 cell = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}
float mist(vec2 p) { return noise(p) * 0.58 + noise(p * 2.05) * 0.28 + noise(p * 4.1) * 0.14; }
void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV);
	float distance_to_edge = min(edge.x, edge.y);
	float corners = (1.0 - smoothstep(0.0, 0.29, edge.x)) * (1.0 - smoothstep(0.0, 0.34, edge.y));
	float border = 1.0 - smoothstep(0.01, 0.105 + corners * 0.095, distance_to_edge);
	vec2 flow = UV * vec2(8.0, 6.0) + vec2(sin(clock_time * 0.38) * 0.65, -clock_time * 0.43);
	float curl = mist(flow + mist(flow * 0.65 + clock_time * 0.17) * 3.0);
	float vapor = smoothstep(0.25, 0.78, curl);
	float veins = pow(max(0.0, 1.0 - abs(curl - 0.57) * 19.0), 3.0);
	float coverage = border * (0.19 + vapor * 0.57 + veins * 0.23) + corners * vapor * 0.25;
	vec3 color = mix(aura_color.rgb * 0.45, aura_color.rgb, vapor);
	color = mix(color, vec3(0.8, 1.0, 0.93), veins * (0.18 + jackpot * 0.22));
	COLOR = vec4(color, min(0.88, coverage * energy));
}
