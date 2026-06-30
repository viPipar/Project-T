/*
Palette Swap (no recolor / recolor)

Exuin
March 14, 2021

+173


Okay, so you want to a palette swap. First, let’s get a sprite. Let’s use a sprite from Pixel Adventure by Pixel Frog because it was the first thing I saw on itch.io. I’ll be using the slime since it has five colors.

First, let’s do the version that doesn’t require you to recolor the sprite. Let’s start by getting the colors of the sprite. Shader colors are vec4s of floats, so you have to convert them to a float between 0 and 1.

Next, get the colors that you want to convert the colors to. You can make them uniforms so that you can edit them easier and so you can just use the color picker instead of trying to convert colors to float vectors.

Now, compare the color of the current pixel to the colors that you’re looking to swap to. Note that float comparison is imprecise so you can’t use ==. You can use the distance() function instead.
*/
shader_type canvas_item;


uniform vec4 original_0: hint_color;
uniform vec4 original_1: hint_color;
uniform vec4 original_2: hint_color;
uniform vec4 original_3: hint_color;
uniform vec4 original_4: hint_color;
uniform vec4 replace_0: hint_color;
uniform vec4 replace_1: hint_color;
uniform vec4 replace_2: hint_color;
uniform vec4 replace_3: hint_color;
uniform vec4 replace_4: hint_color;

const float precision = 0.1;


vec4 swap_color(vec4 color){
	vec4 original_colors[5] = vec4[5] (original_0, original_1, original_2, original_3, original_4);
	vec4 replace_colors[5] = vec4[5] (replace_0, replace_1, replace_2, replace_3, replace_4);
	for (int i = 0; i < 5; i ++) {
		if (distance(color, original_colors[i]) <= precision){
			return replace_colors[i];
		}
	}
	return color;
}


void fragment() {
	COLOR = swap_color(texture(TEXTURE, UV));
}