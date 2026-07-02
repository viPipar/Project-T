shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 1.0) = 0.5;
uniform float opacity : hint_range(0.0, 1.0) = 0.5;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 pos = UV - center;
	
	// Convert to isometric circle (ellipse)
	// Stretch Y by 2 so distance calculation makes an ellipse
	pos.y *= 2.0;
	
	float dist = length(pos);
	
	// Base radius is 0.25 (diameter 0.5 of the square).
	// When blur is low (0.0), it's a sharp circle.
	// When blur is high (1.0), it's a very soft circle.
	float inner_radius = 0.35 - (blur_amount * 0.3);
	float outer_radius = 0.35 + (blur_amount * 0.2);
	
	float alpha = 1.0 - smoothstep(inner_radius, outer_radius, dist);
	
	COLOR = vec4(shadow_color.rgb, alpha * opacity);
}
