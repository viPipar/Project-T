shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.45;
uniform float softness : hint_range(0.01, 1.0) = 0.35;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv * 2.0 - 1.0;
	float dist = length(centered);
	float vignette = smoothstep(1.0 - softness, 1.0, dist);
	vec4 base = texture(SCREEN_TEXTURE, uv);
	vec4 overlay = mix(base, color, vignette * strength);
	COLOR = overlay;
}
