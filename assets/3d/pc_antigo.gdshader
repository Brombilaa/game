shader_type canvas_item;
// Estilo "PC antigo" (direção B do Léo): lavagem leve de cor e 16 bits (5-6-5) com dithering de Bayer 4x4.
uniform sampler2D tela : hint_screen_texture, filter_nearest;
uniform float lavagem : hint_range(0.0, 1.0) = 0.22;

float bayer(vec2 p) {
	ivec2 q = ivec2(mod(floor(p), 4.0));
	int tab[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(tab[q.y * 4 + q.x]) / 16.0 - 0.5;
}

void fragment() {
	vec3 c = texture(tela, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), lavagem);
	float d = bayer(FRAGCOORD.xy) * 0.6;
	c.r = floor(c.r * 31.0 + 0.5 + d) / 31.0;
	c.g = floor(c.g * 63.0 + 0.5 + d) / 63.0;
	c.b = floor(c.b * 31.0 + 0.5 + d) / 31.0;
	COLOR = vec4(c, 1.0);
}
