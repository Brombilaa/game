shader_type spatial;
// Névoa igual à do protótipo em JS: THREE.Fog(0x8c8f86, 41, 81), que mistura a cor da névoa com
// smoothstep(perto, longe, profundidade na vista). A névoa de profundidade do Godot usa outra curva,
// então ela é feita aqui, num quadrado na frente da câmera que lê a profundidade da cena.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D profundidade : hint_depth_texture, filter_nearest;
uniform vec3 cor = vec3(0.2623, 0.2747, 0.2384);  // 0x8c8f86 já em linear (o three.js converte a cor da névoa)
uniform float perto = 41.0;
uniform float longe = 81.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float d = texture(profundidade, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
	float z = -v.z / v.w;
	ALBEDO = cor;
	ALPHA = smoothstep(perto, longe, z);
}
