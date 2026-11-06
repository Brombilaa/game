shader_type canvas_item;
// Estilo "TV antiga" (pedido do Léo, 06/11/2026), por cima do PC antigo: curvatura de tubo, linhas de varredura,
// máscara RGB, aberração cromática, borrão horizontal, ruído, faixa de tracking de VHS, vinheta, bloom e cor em 16 bits.
uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float curvatura : hint_range(0.0, 0.4) = 0.0;
uniform float scan : hint_range(0.0, 1.0) = 0.0;
uniform float scan_altura = 4.0;
uniform float mascara : hint_range(0.0, 1.0) = 0.0;
uniform float aberracao = 0.0;
uniform float borrao = 0.0;
uniform float ruido : hint_range(0.0, 0.3) = 0.0;
uniform float tracking : hint_range(0.0, 2.0) = 0.0;
uniform float vinheta : hint_range(0.0, 1.0) = 0.0;
uniform float bloom : hint_range(0.0, 1.0) = 0.0;
uniform float brilho = 1.0;
uniform float lavagem : hint_range(0.0, 1.0) = 0.2;

float bayer(vec2 p) {
	ivec2 q = ivec2(mod(floor(p), 4.0));
	int tab[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(tab[q.y * 4 + q.x]) / 16.0 - 0.5;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

vec3 amostra(vec2 uv, vec2 px) {
	float b = borrao * px.x;
	vec3 c = texture(tela, uv).rgb * 0.5 + texture(tela, uv + vec2(b, 0.0)).rgb * 0.25 + texture(tela, uv - vec2(b, 0.0)).rgb * 0.25;
	float a = aberracao * px.x * 2.0;
	c.r = mix(c.r, texture(tela, uv + vec2(a, 0.0)).r, step(0.001, aberracao));
	c.b = mix(c.b, texture(tela, uv - vec2(a, 0.0)).b, step(0.001, aberracao));
	return c;
}

void fragment() {
	vec2 uv = SCREEN_UV * 2.0 - 1.0;
	vec2 o = abs(uv.yx) * curvatura;
	uv += uv * o * o * 4.0;
	uv = uv * 0.5 + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 px = SCREEN_PIXEL_SIZE;
		float t = TIME;
		float linha = fract(t * 0.07 + 0.35);
		float d = abs(uv.y - linha);
		uv.x += tracking * 0.012 * exp(-d * 70.0) * sin(uv.y * 400.0 + t * 30.0);
		uv.x += tracking * 0.0008 * sin(uv.y * 90.0 + t * 3.0);
		vec3 c = amostra(uv, px);
		// bloom barato: realça o que passa de 0,6 com amostras afastadas
		vec3 g = (texture(tela, uv + px * 6.0).rgb + texture(tela, uv - px * 6.0).rgb + texture(tela, uv + vec2(-6.0, 6.0) * px).rgb + texture(tela, uv + vec2(6.0, -6.0) * px).rgb) * 0.25;
		c += max(g - 0.55, 0.0) * bloom * 1.6;
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(c, vec3(l), lavagem) * brilho;
		float linhaY = FRAGCOORD.y / scan_altura;
		c *= 1.0 - scan * (0.5 - 0.5 * cos(linhaY * 6.28318));
		vec3 m = vec3(1.0);
		float col = mod(floor(FRAGCOORD.x), 3.0);
		m = vec3(col < 1.0 ? 1.0 : 0.55, (col >= 1.0 && col < 2.0) ? 1.0 : 0.55, col >= 2.0 ? 1.0 : 0.55);
		c *= mix(vec3(1.0), m * 1.25, mascara);
		c += (hash(FRAGCOORD.xy + floor(t * 24.0)) - 0.5) * ruido;
		vec2 v = uv * (1.0 - uv);
		c *= 1.0 - vinheta * (1.0 - clamp(pow(16.0 * v.x * v.y, 0.35), 0.0, 1.0));
		float dd = bayer(FRAGCOORD.xy) * 0.6;
		c = clamp(c, 0.0, 1.0);
		c.r = floor(c.r * 31.0 + 0.5 + dd) / 31.0;
		c.g = floor(c.g * 63.0 + 0.5 + dd) / 63.0;
		c.b = floor(c.b * 31.0 + 0.5 + dd) / 31.0;
		COLOR = vec4(c, 1.0);
	}
}
