shader_type spatial;
// Personagem com sombreamento facetado: a malha ni_lp.glb não tem normais, e o GLTFLoader do three.js
// liga flatShading nesse caso. Aqui a normal de cada face sai das derivadas da posição, igual ao JS.
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D textura : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 cor : source_color = vec4(1.0);
uniform bool usa_textura = true;
uniform vec3 hemi_ceu = vec3(1.0);
uniform vec3 hemi_chao = vec3(1.0);

void fragment() {
	vec3 base = cor.rgb;
	if (usa_textura) {
		base *= texture(textura, UV).rgb;
	}
	ALBEDO = base;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) {
		n = -n;
	}
	NORMAL = n;
	// HemisphereLight do JS: faces para cima pegam o céu claro, para baixo o chão escuro.
	// O ambiente do Godot é uma cor só (a média dos dois); este fator devolve a variação.
	float t = 0.5 * (INV_VIEW_MATRIX * vec4(n, 0.0)).y + 0.5;
	ALBEDO *= mix(hemi_chao, hemi_ceu, t);
}
