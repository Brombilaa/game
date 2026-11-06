shader_type spatial;
// Só para calibragem (tools/capturar_parque3d.gd com IDMAT=1): pinta cada material com o seu número.
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
uniform sampler2D tex : filter_nearest;
uniform vec3 cor;
uniform bool usa_alfa = false;
uniform vec3 escala = vec3(1.0);
uniform vec3 desloc = vec3(0.0);
void vertex() { UV = UV * escala.xy + desloc.xy; }
void fragment() {
	ALBEDO = cor;
	if (usa_alfa) {
		ALPHA = texture(tex, UV).a;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
	}
}
