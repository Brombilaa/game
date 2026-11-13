shader_type canvas_item;
// Estilo "PC antigo" (direção B do Léo, 06/11/2026): cópia do pós-processamento do protótipo three.js
// (parque3d_bake.html) mais o filtro CSS e o grão de filme da página. Sem efeito de TV.
// 1) no espaço linear: lavagem de 8% (mix com a luminância 0,92), c*0,97+0,008, depois gama 1/2,2
// 2) 16 bits (5-6-5) com dithering de Bayer 4x4 a 0,6
// 3) filter: saturate(.84) contrast(1.06) sobre o resultado
// 4) grão: ruído 256x256 esticado na tela, mix-blend-mode: overlay a 7%
uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float nevoa : hint_range(0.0, 1.0) = 0.0;  // a névoa agora é do próprio 3D (Environment, 41 a 81 unidades)
// Correção de cor medida contra a referência (regressão em linear): o Godot sai um pouco menos saturado e mais verde.
uniform float corr_saturacao = 1.17;
uniform vec3 corr_ganho = vec3(0.93, 0.85, 0.91);
// Cenários novos (cenario3d.gd): a imagem do SubViewport chega em sRGB e é linearizada aqui. O parque foi calibrado sem isso.
uniform bool entrada_srgb = false;
uniform vec3 cor_nevoa : source_color = vec3(0.549, 0.561, 0.525);

float bayer(vec2 p) {
	ivec2 q = ivec2(mod(floor(p), 4.0));
	int tab[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(tab[q.y * 4 + q.x]) / 16.0 - 0.5;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float ruido(vec2 uv) {
	vec2 p = uv * 256.0 - 0.5;
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec3 s = texture(tela, SCREEN_UV).rgb;
	vec3 c = s;
	if (entrada_srgb) {
		c = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
	}
	float lz = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = max(mix(vec3(lz), c, corr_saturacao), 0.0) * corr_ganho;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 0.92);
	c = c * 0.97 + 0.008;
	c = pow(max(c, 0.0), vec3(1.0 / 2.2));
	float dd = bayer(FRAGCOORD.xy) * 0.6;
	c = clamp(c, 0.0, 1.0);
	c.r = floor(c.r * 31.0 + 0.5 + dd) / 31.0;
	c.g = floor(c.g * 63.0 + 0.5 + dd) / 63.0;
	c.b = floor(c.b * 31.0 + 0.5 + dd) / 31.0;
	// filter CSS
	float lc = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(lc), c, 0.84);
	c = clamp((c - 0.5) * 1.06 + 0.5, 0.0, 1.0);
	// grão (overlay a 7%)
	float n = ruido(SCREEN_UV);
	vec3 ov = mix(2.0 * c * n, 1.0 - 2.0 * (1.0 - c) * (1.0 - n), step(0.5, c));
	c = mix(c, ov, 0.07);
	COLOR = vec4(c, 1.0);
}
