shader_type canvas_item;
// Estilo "PC antigo" (direção B do Léo, 06/11/2026), igual ao protótipo three.js: cor levemente lavada, preto levantado
// e 16 bits (5-6-5) com dithering ordenado de Bayer 4x4. Sem efeito de TV.
uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float lavagem : hint_range(0.0, 1.0) = 0.08;
uniform float ganho = 0.97;
uniform float piso = 0.008;
uniform float gama = 1.0;  // levanta os médios: o three.js tratava as texturas como lineares e saía mais claro
uniform float nevoa : hint_range(0.0, 1.0) = 0.15;  // névoa do protótipo: Fog(0x8c8f86, 41, 81) a 47 unidades da câmera
uniform vec3 cor_nevoa : source_color = vec3(0.549, 0.561, 0.525);
uniform vec3 tom = vec3(1.0, 1.0, 1.08);  // esfria o conjunto: o glb sai mais amarelo que o render do three.js

float bayer(vec2 p) {
	ivec2 q = ivec2(mod(floor(p), 4.0));
	int tab[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(tab[q.y * 4 + q.x]) / 16.0 - 0.5;
}

void fragment() {
	vec3 c = texture(tela, SCREEN_UV).rgb;
	c = mix(c, cor_nevoa, nevoa);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = pow(max(mix(c, vec3(l), lavagem), 0.0), vec3(gama)) * ganho * tom + piso;
	float d = bayer(FRAGCOORD.xy) * 0.6;
	c = clamp(c, 0.0, 1.0);
	c.r = floor(c.r * 31.0 + 0.5 + d) / 31.0;
	c.g = floor(c.g * 63.0 + 0.5 + d) / 63.0;
	c.b = floor(c.b * 31.0 + 0.5 + d) / 31.0;
	COLOR = vec4(c, 1.0);
}
