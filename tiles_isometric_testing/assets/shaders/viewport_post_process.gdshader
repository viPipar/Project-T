shader_type canvas_item;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_softness : hint_range(0.01, 1.0) = 0.45;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	
	// Local Vignette
	vec2 centered = UV * 2.0 - 1.0;
	float dist = length(centered);
	float vignette = smoothstep(1.0 - vignette_softness, 1.0, dist);
	
	COLOR = mix(base, vignette_color, vignette * vignette_strength);
}
