shader_type canvas_item;
// Fundo do menu de pausa: o jogo parado, escurecido e com menos cor (desfoque opcional, desligado no modelo C).

uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float raio = 7.0;  // desfoque, em pixels da janela
uniform float brilho = 0.32;
uniform float cor = 0.6;  // 1 = cor original, 0 = cinza


void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * raio;
	vec3 soma = texture(tela, SCREEN_UV).rgb;
	float peso = 1.0;
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5235988;
		vec2 d = vec2(cos(a), sin(a));
		soma += texture(tela, SCREEN_UV + d * px * 0.34).rgb;
		soma += texture(tela, SCREEN_UV + d * px * 0.67).rgb;
		soma += texture(tela, SCREEN_UV + d * px).rgb;
		peso += 3.0;
	}
	vec3 c = soma / peso;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(lum), c, cor) * brilho;
	// vinheta leve, como no menu inicial
	vec2 v = SCREEN_UV - 0.5;
	c *= 1.0 - dot(v, v) * 0.9;
	COLOR = vec4(c, 1.0);
}
