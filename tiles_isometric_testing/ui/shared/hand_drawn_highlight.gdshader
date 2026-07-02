shader_type canvas_item;

uniform vec4 fill_color : source_color = vec4(0.2, 0.6, 1.0, 0.3);
uniform vec4 edge_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float edge_thickness : hint_range(0.0, 0.5) = 0.12;

// Wobble / Boiling effect parameters
uniform float wobble_speed : hint_range(0.0, 20.0) = 8.0;
uniform float wobble_strength : hint_range(0.0, 0.1) = 0.015;

// Pulse parameters
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;

// Border hiding uniforms for adjacent tile highlights
uniform bool hide_tl = false;
uniform bool hide_tr = false;
uniform bool hide_bl = false;
uniform bool hide_br = false;

// Pseudo-random noise function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    
    // Quantize time to create a "stop-motion" boiling effect typical of hand-drawn art
    float time_step = floor(TIME * wobble_speed);
    
    // Add wobble to UV
    vec2 wobble = vec2(
        hash(UV + time_step * 0.1) - 0.5,
        hash(UV - time_step * 0.2) - 0.5
    ) * wobble_strength;
    
    vec2 noise_uv = UV + wobble;
    vec2 d = abs(noise_uv - center) * 2.0;
    
    // Distance field for an isometric diamond in a 2:1 bounding box
    float dist = d.x + d.y;
    
    // Soft anti-aliased edge instead of hard discard for better visual
    float alpha = smoothstep(1.0 + wobble_strength, 1.0 - wobble_strength, dist);
    
    vec4 final_color = fill_color;
    
    // Draw the bright edge
    float is_edge = smoothstep(1.0 - edge_thickness, 1.0 - edge_thickness + 0.02, dist);
    
    // Conditionally hide edge segments based on adjacent neighbors in isometric projection
    float dx = noise_uv.x - center.x;
    float dy = noise_uv.y - center.y;
    if (is_edge > 0.0) {
        if (dx < 0.0 && dy < 0.0 && hide_tl) {
            is_edge = 0.0;
        } else if (dx > 0.0 && dy < 0.0 && hide_tr) {
            is_edge = 0.0;
        } else if (dx < 0.0 && dy > 0.0 && hide_bl) {
            is_edge = 0.0;
        } else if (dx > 0.0 && dy > 0.0 && hide_br) {
            is_edge = 0.0;
        }
    }
    
    final_color = mix(final_color, edge_color, is_edge);
    
    // Multiply master alpha based on distance field to cut out the diamond shape
    final_color.a *= alpha;
    
    // Add pulsing glow effect
    float pulse = (sin(TIME * pulse_speed) * 0.5 + 0.5) * 0.4 + 0.6; // varies from 0.6 to 1.0
    final_color.a *= pulse;
    
    COLOR = final_color;
}
