shader_type spatial;
// Névoa de distância dos cenários da missão 1, igual à THREE.Fog do protótipo: mistura a cor da névoa
// com smoothstep(perto, longe, profundidade) em espaço LINEAR. No Compatibility a tela 3D já está em
// sRGB e a transparência comum mistura nesse espaço, o que deixa a névoa bem mais fraca sobre áreas
// escuras. Por isso este quadro lê a tela, converte, mistura e devolve a cor pronta (sem alfa).
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D tela : hint_screen_texture, filter_nearest;
uniform sampler2D profundidade : hint_depth_texture, filter_nearest;
uniform vec3 cor = vec3(0.2623, 0.2747, 0.2384);  // linear
uniform float perto = 41.0;
uniform float longe = 81.0;
uniform float forca = 1.0;
// Névoa baixa: camada rente ao chão, presa ao mundo, que se mexe devagar. 0 desliga.
uniform float baixa = 0.0;
uniform float altura = 0.7;
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
vec3 para_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 para_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float d = texture(profundidade, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
	float z = -v.z / v.w;
	vec3 c = para_linear(texture(tela, SCREEN_UV).rgb);
	c = mix(c, cor, clamp(smoothstep(perto, longe, z) * forca, 0.0, 1.0));
	if (baixa > 0.0 && d < 1.0) {
		vec3 mundo = (INV_VIEW_MATRIX * vec4(v.xyz / v.w, 1.0)).xyz;
		float n = fbm(mundo.xz * 0.35 + vec2(TIME * 0.05, TIME * 0.02));
		c = mix(c, cor_baixa, clamp((1.0 - smoothstep(0.0, altura, mundo.y)) * smoothstep(0.25, 0.85, n) * baixa, 0.0, 1.0));
	}
	ALBEDO = para_srgb(c);  // medido no Compatibility 4.3: a cor de um material sem luz vai direto para a tela, que está em sRGB
}
