shader_type canvas_item;

uniform float screen_height = 270.0;
uniform float diff_mod = 0.075;

void fragment() {
	float diff_x = diff_mod * sin((10.0 * UV.y) + (2.0 * TIME));
	COLOR = texture(TEXTURE, vec2(UV.x + diff_x, UV.y));
	COLOR = mix(COLOR, vec4(0.0), float(int(UV.y * screen_height) % 2));
}