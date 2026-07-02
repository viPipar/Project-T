shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shine_speed : hint_range(0.0, 10.0) = 1.5;
uniform float shine_size : hint_range(0.01, 1.0) = 0.15;
// Angle in degrees. 45 degrees makes it sweep diagonally across the square.
uniform float shine_angle : hint_range(0.0, 360.0) = 45.0;

void fragment() {
    // Multiply the texture by our base_color
    vec4 tex_color = texture(TEXTURE, UV) * base_color;
    
    // Rotate UV for the sweep angle
    float angle = radians(shine_angle);
    mat2 rot = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
    vec2 rotated_uv = rot * (UV - 0.5) + 0.5;
    
    // Calculate sweeping line position based on TIME
    // To make it sweep smoothly, we use mod and offset it so it starts before the sprite and ends after
    float pos = mod(TIME * shine_speed, 2.0) - 0.5; 
    
    // Calculate distance from current UV to the sweeping line
    float dist = abs(rotated_uv.x - pos);
    
    // Create a smooth gradient for the shine line
    float shine = smoothstep(shine_size, 0.0, dist);
    
    // Add the shine color to the base texture
    vec3 final_rgb = tex_color.rgb + (shine_color.rgb * shine * tex_color.a);
    
    COLOR = vec4(final_rgb, tex_color.a);
}
