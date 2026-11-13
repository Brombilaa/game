shader_type spatial;
// Camadas claras e sem luz por cima do cenário (névoa rente ao chão, teias): no protótipo a transparência
// mistura em espaço linear; no Compatibility mistura em sRGB e uma camada clara e fraca quase some sobre
// o escuro. Elevar o alfa a 1/2,2 devolve a mesma presença sobre fundo escuro.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 cor : source_color = vec4(1.0);
uniform sampler2D textura : source_color, filter_linear_mipmap, repeat_enable;
uniform bool tem_textura = false;
uniform float expoente = 0.4545;

void fragment() {
	vec4 t = cor;
	if (tem_textura) {
		t *= texture(textura, UV);
	}
	ALBEDO = t.rgb;
	ALPHA = pow(clamp(t.a, 0.0, 1.0), expoente);
}
