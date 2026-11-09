shader_type canvas_item;
// Vidro fosco do HUD (Léo, 09/11/2026, "fosco profundo"): desfoca o que está atrás da placa, escurece
// com um degradê, e põe grão fino e uma trama diagonal bem leve. Desenhado antes do HUD (HudBlur).

uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float raio = 11.0;  // desfoque, em pixels da janela
uniform vec4 tom_topo : source_color = vec4(0.086, 0.086, 0.11, 0.66);
uniform vec4 tom_base : source_color = vec4(0.016, 0.016, 0.024, 0.8);
uniform float grao = 0.09;


float ruido(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}


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
	vec3 cor = soma / peso;
	float lum = dot(cor, vec3(0.299, 0.587, 0.114));
	cor = mix(vec3(lum), cor, 1.15);  // um pouco mais de saturação, como o vidro de verdade
	vec4 tom = mix(tom_topo, tom_base, UV.y);
	cor = mix(cor, tom.rgb, tom.a);
	vec2 p = floor(FRAGCOORD.xy);
	cor += (ruido(p) - 0.5) * grao;
	cor += step(0.5, fract((p.x + p.y) / 5.0)) * 0.012;
	COLOR = vec4(cor, 1.0);
}
