shader_type spatial;
// Personagem com sombreamento facetado: a malha ni_lp.glb não tem normais, e o GLTFLoader do three.js
// liga flatShading nesse caso. Aqui a normal de cada face sai das derivadas da posição, igual ao JS.
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D textura : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 cor = vec4(1.0);  // multiplicador linear (sem source_color: valores acima de 1 não podem passar pela conversão sRGB)
uniform bool usa_textura = true;
// Contraste da textura em volta da cor média dela (em sRGB), medido contra a referência: no Godot o casaco
// mostrava manchas frias e a pele ficava pálida.
uniform vec3 media_textura = vec3(0.098, 0.086, 0.078);  // cor típica do casaco (mediana da textura): o contraste gira em volta dela
uniform vec3 contraste = vec3(1.0);
// Luz fria somada nas sombras do personagem: no JS o casaco na sombra sai cinza neutro (céu azulado do
// HemisphereLight); no Godot saía marrom. Medido contra a referência.
uniform vec3 luz_fria = vec3(0.0);

void fragment() {
	vec3 base = cor.rgb;
	if (usa_textura) {
		vec3 t = pow(texture(textura, UV).rgb, vec3(1.0 / 2.2));
		t = max(media_textura + (t - media_textura) * contraste, vec3(0.0));
		base *= pow(t, vec3(2.2));
	}
	ALBEDO = base;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) {
		n = -n;
	}
	NORMAL = n;
	EMISSION = luz_fria;
}
