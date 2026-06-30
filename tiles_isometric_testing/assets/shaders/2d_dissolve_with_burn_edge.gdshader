/*
It’s a modification of the 2D Simple dissolve shader to add a burn edge. 

How to setup

Add the shader to any node with a texture (TextureRect, Sprite2D, etc..)
Add a NoiseTexture2D
Width and height of texture should be set depending on the size of your texture. A too small texture will result in a blurry output
Setup the noise using the noise you prefer. Simplex Smooth works well
Change the frequency to change the look of the dissolve effect. 
Choose the burn size and burn color you want
How to use

Dissolve value: 0 (dissolved) to 1 (not dissolved)
Burn size: size of the burn edge (0.04 works well usually)
Burn color: color of the burn edge
Dissolve texture: noise texture used to create the dissolve effect
*/

shader_type canvas_item;

uniform sampler2D dissolve_texture : source_color;
uniform float dissolve_value : hint_range(0,1);
uniform float burn_size: hint_range(0.0, 1.0, 0.01);
uniform vec4 burn_color: source_color;

void fragment(){
    vec4 main_texture = texture(TEXTURE, UV);
    vec4 noise_texture = texture(dissolve_texture, UV);
	
	// This is needed to avoid keeping a small burn_color dot with dissolve being 0 or 1
	// is there another way to do it?
	float burn_size_step = burn_size * step(0.001, dissolve_value) * step(dissolve_value, 0.999);
	float threshold = smoothstep(noise_texture.x-burn_size_step, noise_texture.x, dissolve_value);
	float border = smoothstep(noise_texture.x, noise_texture.x + burn_size_step, dissolve_value);
	
	COLOR.a *= threshold;
	COLOR.rgb = mix(burn_color.rgb, main_texture.rgb, border);
}