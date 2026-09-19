shader_type canvas_item;
render_mode unshaded;
uniform vec4 aura_color : source_color = vec4(0.10, 0.97, 0.54, 1.0);
uniform float energy = 0.0;
uniform float clock_time = 0.0;
uniform float tier = 0.0;
uniform float beat = 0.0;
uniform float arrival = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 cell = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}
float mist(vec2 p) { return noise(p) * 0.64 + noise(p * 2.03) * 0.26 + noise(p * 4.11) * 0.10; }
void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV);
	float distance_to_edge = min(edge.x, edge.y);
	float jackpot = step(2.5, tier);
	float rocket = step(3.5, tier);
	float corners = (1.0 - smoothstep(0.0, 0.24, edge.x)) * (1.0 - smoothstep(0.0, 0.28, edge.y));
	float width = 0.027 + tier * 0.020 + corners * (0.035 + tier * 0.009);
	float border = 1.0 - smoothstep(0.0, width, distance_to_edge);
	vec2 flow = UV * vec2(9.0, 6.5) + vec2(sin(clock_time * 0.32) * 0.55, -clock_time * (0.20 + tier * 0.035));
	float curl = mist(flow + noise(flow * 0.63 + clock_time * 0.14) * 2.5);
	float vapor = smoothstep(0.24, 0.78, curl);
	float veins = pow(max(0.0, 1.0 - abs(curl - 0.56) * 20.0), 3.0);
	float coverage = border * (0.18 + vapor * 0.69 + veins * 0.24) + corners * vapor * tier * 0.035;
	coverage *= 1.0 + jackpot * beat * 0.14 + arrival * 0.18;
	// The center receives at most a faint 3–6% island-colour wash. The energy is at the edges.
	float wash = jackpot * (0.035 + rocket * 0.025) * (0.78 + beat * 0.22);
	vec3 color = mix(aura_color.rgb * 0.62, aura_color.rgb, vapor);
	color = mix(color, mix(aura_color.rgb, vec3(1.0), 0.73), veins * (0.20 + jackpot * 0.22));
	COLOR = vec4(color, min(0.76, (coverage + wash) * energy));
}
