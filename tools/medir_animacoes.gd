extends SceneTree
# Mede como as animações 3D se comportam quando o jogo as dirige de verdade (posição andando, troca de animação,
# giro), com o relógio fixo em 60 quadros por segundo. Não precisa de janela:
#   godot --headless --path . -s tools/medir_animacoes.gd -- personagem [saida.json]
# Cenas: andar e parar, andar e agachar, giro parado, giro andando, trocar de caminhada para corrida (o jogo ainda
# não usa a corrida, mas a biblioteca tem). Saída: escorregada do pé de apoio, picos de velocidade dos ossos
# nas trocas, tempo que o corpo leva para parar, e quanto o pé sai do lugar durante um giro parado.
const DT := 1000.0 / 60.0
const VEL := 2.8  # unidades 3D por segundo (SPEED 180 px / 64)

var ag: Agente3D
var t := 0.0
var rec := []  # por quadro: {t, anim, yaw, pe_e, pe_d, quadril, ossos}
var ossos := []


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var quem: String = args[0] if args.size() > 0 else "fernando3d"
	var saida: String = args[1] if args.size() > 1 else "/tmp/claude/work/medidas_%s.json" % quem
	ag = Agente3D.new(quem)
	root.add_child(ag)
	Agente3D.relogio_teste = 0
	var rel := {}
	# Cena 1: parado, anda reto, para.
	rel["andar_parar"] = await _cena([[1.0, "idle", 0.0, 0.0], [2.5, "walk", 0.0, VEL], [1.5, "idle", 0.0, 0.0]])
	# Cena 2: anda, agacha andando, levanta.
	rel["andar_agachar"] = await _cena([[0.5, "idle", 0.0, 0.0], [1.5, "walk", 0.0, VEL], [1.5, "crouch_walk", 0.0, VEL * 0.5], [1.5, "walk", 0.0, VEL], [1.0, "idle", 0.0, 0.0]])
	# Cena 3: giro parado de 135 graus.
	rel["giro_parado"] = await _cena([[1.0, "idle", 0.0, 0.0], [1.5, "idle", deg_to_rad(135.0), 0.0], [0.5, "idle", deg_to_rad(135.0), 0.0]])
	# Cena 4: anda e vira 90 graus no meio do caminho.
	rel["giro_andando"] = await _cena([[1.0, "walk", 0.0, VEL], [2.0, "walk", deg_to_rad(90.0), VEL]])
	# Cena 5: caminhada para corrida e volta (a biblioteca tem; o jogo ainda não usa).
	rel["andar_correr"] = await _cena([[1.0, "walk", 0.0, VEL], [1.5, "run", 0.0, VEL * 1.6], [1.0, "walk", 0.0, VEL]])
	var f := FileAccess.open(saida, FileAccess.WRITE)
	f.store_string(JSON.stringify(rel, "  "))
	print(JSON.stringify(rel, "  "))
	quit()


# trechos: [duração s, animação, yaw alvo, velocidade u/s]
func _cena(trechos: Array) -> Dictionary:
	ag.position = Vector3.ZERO
	ag.rotation.y = trechos[0][2]
	ag._ultimo_giro = -1
	ag.atual = ""
	ag._ultima_pos = Vector3.INF
	ag._andado = 0.0
	ag._ultima_pose = -1
	var sk := ag.esqueleto
	var pe := [sk.find_bone("mixamorig_LeftFoot"), sk.find_bone("mixamorig_RightFoot")]
	var quad := sk.find_bone("mixamorig_Hips")
	var quadros := []
	var yaw := trechos[0][2] as float
	for tr in trechos:
		var dur: float = tr[0]
		yaw = tr[2]
		var n := int(dur * 60.0)
		for i in n:
			Agente3D.relogio_teste += int(round(DT))
			ag.virar(yaw)
			var frente := Vector3(sin(ag.rotation.y), 0, cos(ag.rotation.y))
			ag.position += frente * float(tr[3]) / 60.0
			ag.pose(tr[1], 0.0, false)
			await process_frame
			var m := sk.global_transform
			var q := {"anim": tr[1], "yaw": ag.rotation.y, "alvo": yaw, "v": tr[3], "pos": ag.position}
			q["pe"] = [(m * sk.get_bone_global_pose(pe[0])).origin, (m * sk.get_bone_global_pose(pe[1])).origin]
			q["quad"] = (m * sk.get_bone_global_pose(quad)).origin
			quadros.append(q)
	return _analisar(quadros)


func _analisar(q: Array) -> Dictionary:
	var out := {}
	# Velocidade de cada pé no mundo; apoio = pé mais baixo do par (altura relativa ao menor y visto).
	var ymin := 1e9
	for f in q:
		for p in f["pe"]:
			ymin = minf(ymin, (p as Vector3).y)
	var desliza := []  # velocidade horizontal (u/s) do pé em apoio, quando o personagem anda
	var pico := 0.0
	var spikes := []
	for i in range(1, q.size()):
		for k in 2:
			var a: Vector3 = q[i - 1]["pe"][k]
			var b: Vector3 = q[i]["pe"][k]
			var v := Vector2(b.x - a.x, b.z - a.z).length() * 60.0
			var apoio := b.y < ymin + 0.06
			if apoio and float(q[i]["v"]) > 0.0:
				desliza.append(v)
			# aceleração do pé: salto de velocidade entre quadros (pop)
			if i >= 2:
				var c: Vector3 = q[i - 2]["pe"][k]
				var v0 := Vector2(a.x - c.x, a.z - c.z).length() * 60.0
				var acel := absf(v - v0) * 60.0
				pico = maxf(pico, acel)
				if acel > 250.0:
					spikes.append(snappedf(i / 60.0, 0.01))
	desliza.sort()
	out["desliza_mediana"] = snappedf(desliza[desliza.size() / 2], 0.001) if desliza.size() > 0 else 0.0
	out["desliza_p95"] = snappedf(desliza[int(desliza.size() * 0.95)], 0.001) if desliza.size() > 0 else 0.0
	out["pico_aceleracao_pe"] = snappedf(pico, 1.0)
	out["quadros_com_pop"] = spikes.size()
	out["instantes_pop"] = spikes.slice(0, 12)
	# Pé parado durante giro (idle com yaw mudando): quanto os pés andam no mundo.
	var giro := 0.0
	var rodou := 0.0
	for i in range(1, q.size()):
		if float(q[i]["v"]) == 0.0 and absf(angle_difference(q[i - 1]["yaw"], q[i]["yaw"])) > 0.001:
			rodou += absf(angle_difference(q[i - 1]["yaw"], q[i]["yaw"]))
			for k in 2:
				var a: Vector3 = q[i - 1]["pe"][k]
				var b: Vector3 = q[i]["pe"][k]
				giro += Vector2(b.x - a.x, b.z - a.z).length()
	out["giro_parado_graus"] = snappedf(rad_to_deg(rodou), 1.0)
	out["giro_parado_pe_andou"] = snappedf(giro, 0.001)
	# Tempo para o corpo (quadril) se aproximar da pose parada depois de parar: usa o último trecho.
	return out
