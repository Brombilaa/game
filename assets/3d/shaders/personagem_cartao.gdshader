shader_type spatial;
// Personagem do jogo dentro do parque 3D: um quadro da folha (já renderizada no estilo PC antigo) num cartão
// em pé, virado para a câmera, nos pés do personagem. Assim árvores e objetos na frente escondem quem está
// atrás, pela profundidade do 3D. O mundo passa depois pelo filtro PC antigo (pc_antigo.gdshader); como a
// folha já tem esse visual, a cor aqui é a inversa do filtro, para o personagem sair igual ao desenho 2D.
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;

uniform sampler2D folha : filter_linear;  // sem source_color: lê os valores sRGB como estão
uniform vec4 regiao = vec4(0.0, 0.0, 1.0, 1.0);  // quadro na folha: x, y, largura, altura (0 a 1)
uniform bool espelhar = false;
uniform float clarao = 0.0;  // pisca branco ao levar dano (0 a 1)
// Mesmos valores do pc_antigo.gdshader.
uniform float corr_saturacao = 1.17;
uniform vec3 corr_ganho = vec3(0.93, 0.85, 0.91);

vec3 inverso_filtro(vec3 t) {
	vec3 c = (t - 0.5) / 1.06 + 0.5;  // contraste CSS
	float lc = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = lc + (c - lc) / 0.84;  // saturate(.84)
	c = pow(clamp(c, 0.0, 1.0), vec3(2.2));  // gama
	c = (c - 0.008) / 0.97;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = l + (c - l) / 0.92;  // lavagem
	c = c / corr_ganho;
	float lz = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = lz + (c - lz) / corr_saturacao;
	return max(c, 0.0);
}

void fragment() {
	vec2 uv = UV;
	if (espelhar) {
		uv.x = 1.0 - uv.x;
	}
	vec4 t = texture(folha, regiao.xy + uv * regiao.zw);
	ALBEDO = inverso_filtro(mix(t.rgb, vec3(1.0), clarao * 0.75));
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
