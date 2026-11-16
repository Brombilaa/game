shader_type canvas_item;
// Aviso de SAN (Léo 15/11: modelo C com B, sem visor de batimento). Só o mundo: o HUD é desenhado por cima.
// B: bordas da tela escurecem em azul e pulsam. C: tremor com cores separadas, cópia fantasma de quem está
// em ruptura e, na loucura, tela vermelha que depois perde a cor.
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float aberr = 0.0;        // separação das cores (fração da largura)
uniform vec2 shake = vec2(0.0);   // deslocamento do tremor (UV)
uniform float vignette = 0.0;     // 0..1, força da borda escura
uniform vec3 vig_color = vec3(0.03, 0.055, 0.16);
uniform float red = 0.0;          // 0..1, véu vermelho da loucura
uniform float gray = 0.0;         // 0..1, perda de cor depois da loucura
uniform vec2 ghost_uv = vec2(0.5);
uniform vec2 ghost_size = vec2(0.08, 0.2);
uniform float ghost = 0.0;        // 0..1, cópia fantasma em volta de quem está em ruptura
uniform vec2 ghost_offset = vec2(0.012, -0.004);

void fragment() {
	vec2 uv = SCREEN_UV + shake;
	vec3 col;
	col.r = texture(screen, uv + vec2(aberr, 0.0)).r;
	col.g = texture(screen, uv).g;
	col.b = texture(screen, uv - vec2(aberr, aberr * 0.3)).b;
	if (ghost > 0.0) {
		float d = length((SCREEN_UV - ghost_uv) / ghost_size);
		float w = ghost * (1.0 - smoothstep(0.55, 1.0, d));
		vec3 g = texture(screen, uv - ghost_offset).rgb;
		col = mix(col, mix(g, vec3(0.12, 0.2, 0.47), 0.45), w * 0.4);
	}
	float v = smoothstep(0.32, 0.95, length((SCREEN_UV - 0.5) * vec2(1.55, 1.25)));
	col = mix(col, vig_color, clamp(v * vignette, 0.0, 0.92));
	col = mix(col, vec3(0.55, 0.02, 0.02), red);
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l), gray);
	COLOR = vec4(col, 1.0);
}
