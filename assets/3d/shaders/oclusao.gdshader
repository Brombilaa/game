shader_type spatial;
// Oclusão de ambiente em espaço de tela (SSAO) feita à mão, porque o renderer Compatibility do Godot 4.3 não tem SSAO.
// Um quadrado cobre a tela, lê a profundidade da cena e escurece (blend_mul) onde a vizinhança está mais perto
// da câmera do que o ponto: cantos, pé de muro, contato dos personagens e pneus com o chão, miolo das folhagens.
render_mode unshaded, blend_mul, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D profundidade : hint_depth_texture, filter_nearest;
uniform float raio = 0.45;        // em unidades do mundo
uniform float forca = 0.9;
uniform float vies = 0.02;
uniform int amostras = 16;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// (no Compatibility 4.3 a textura de profundidade só pode ser lida dentro de fragment(), então a leitura fica lá)
vec3 posicao(vec2 uv, float d, mat4 inv_proj) {
	vec4 ndc = vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
	vec4 v = inv_proj * ndc;
	return v.xyz / v.w;
}

float ruido(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 p = posicao(SCREEN_UV, texture(profundidade, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	// tamanho do pixel em unidades (câmera ortográfica): diferença de posição entre vizinhos
	float unidades_por_uv = length(dFdx(p).xy) * VIEWPORT_SIZE.x;
	float r_uv = raio / max(unidades_por_uv, 1e-4);
	// normal do ponto a partir das derivadas da posição (sem isso, o chão inclinado na vista se ocultaria sozinho)
	vec3 n = normalize(cross(dFdx(p), dFdy(p)));
	if (n.z < 0.0) n = -n;
	float ang0 = ruido(FRAGCOORD.xy) * 6.2831;
	float oc = 0.0;
	for (int i = 0; i < amostras; i++) {
		float t = (float(i) + 0.5) / float(amostras);
		float a = ang0 + float(i) * 2.39996;  // espiral de ouro
		vec2 o = vec2(cos(a), sin(a)) * sqrt(t) * r_uv;
		vec2 uq = SCREEN_UV + vec2(o.x, o.y * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y);
		vec3 q = posicao(uq, texture(profundidade, uq).r, INV_PROJECTION_MATRIX);
		vec3 d = q - p;
		float h = dot(d, n);  // altura da amostra acima do plano do ponto
		float dist = length(d);
		float alcance = 1.0 - smoothstep(raio, raio * 2.5, dist);
		oc += step(vies, h) * clamp(h / max(dist, 1e-4), 0.0, 1.0) * alcance;
	}
	oc /= float(amostras);
	float ao = 1.0 - forca * oc;
	ALBEDO = vec3(ao);
}
