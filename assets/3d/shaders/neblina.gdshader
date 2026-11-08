shader_type spatial;
// Névoa igual à do protótipo em JS: THREE.Fog(0x8c8f86, 41, 81), que mistura a cor da névoa com
// smoothstep(perto, longe, profundidade na vista). A névoa de profundidade do Godot usa outra curva,
// então ela é feita aqui, num quadrado na frente da câmera que lê a profundidade da cena.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D profundidade : hint_depth_texture, filter_nearest;
uniform vec3 cor = vec3(0.2623, 0.2747, 0.2384);  // 0x8c8f86 já em linear (o three.js converte a cor da névoa)
uniform float perto = 41.0;
uniform float longe = 81.0;
uniform float forca = 1.0;  // multiplica a névoa de distância do JS (1 = igual ao protótipo)
// Névoa baixa (Léo, 08/11: a névoa de distância parecia um PNG por cima): camada rente ao chão que
// vai sumindo com a altura e se mexe devagar, presa ao mundo e não à tela. 0 desliga.
uniform float baixa = 0.0;
uniform float altura = 0.7;  // unidades 3D (o herói tem 2,2): só até a canela (Léo, 08/11: forte demais)
uniform vec3 cor_baixa = vec3(0.30, 0.31, 0.29);

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	return ruido(p) * 0.55 + ruido(p * 2.1 + 3.7) * 0.3 + ruido(p * 4.3 + 7.1) * 0.15;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float d = texture(profundidade, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
	float z = -v.z / v.w;
	float distante = smoothstep(perto, longe, z) * forca;
	float rente = 0.0;
	if (baixa > 0.0 && d < 1.0) {
		vec3 mundo = (INV_VIEW_MATRIX * vec4(v.xyz / v.w, 1.0)).xyz;
		float n = fbm(mundo.xz * 0.35 + vec2(TIME * 0.05, TIME * 0.02));
		rente = (1.0 - smoothstep(0.0, altura, mundo.y)) * smoothstep(0.25, 0.85, n) * baixa;  // fiapos com buracos, não um véu contínuo
	}
	float a = clamp(distante + rente - distante * rente, 0.0, 1.0);
	ALBEDO = mix(cor_baixa, cor, distante / max(distante + rente, 0.0001));
	ALPHA = a;
}
