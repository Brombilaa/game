class_name SaveSlots
extends RefCounted
# Política de save aprovada (DEC-2026-10-29-01, docs/save-e-build.md):
# um slot automático, gravado ao entrar em área/zona segura e no início do
# combate, e 3 slots manuais, só fora de combate. Morte do grupo volta ao
# automático. Quem dispara o autosave é a cena; aqui só ficam slots e regras.

const DIR := "user://saves"
const AUTO := "auto"
const MANUAL_COUNT := 3


static func manual(n: int) -> String:
	return "manual_%d" % n


static func ids() -> Array[String]:
	var result: Array[String] = [AUTO]
	for n in range(1, MANUAL_COUNT + 1):
		result.append(manual(n))
	return result


static func is_valid(slot: String) -> bool:
	return slot in ids()


# Save manual não é permitido no meio do combate.
static func can_save_manual(in_combat: bool) -> bool:
	return not in_combat


static func path_for(slot: String, dir := DIR) -> String:
	return dir.path_join(slot + ".json")


static func save(slot: String, data: Dictionary, dir := DIR) -> Error:
	if not is_valid(slot):
		return ERR_INVALID_PARAMETER
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		return err
	return SaveGame.write(path_for(slot, dir), data)


# Devolve {} se o slot estiver vazio ou inválido.
static func load_slot(slot: String, dir := DIR) -> Dictionary:
	if not is_valid(slot):
		return {}
	return SaveGame.read(path_for(slot, dir))


# Resumo para a tela de carregar: um item por slot, na ordem de ids().
static func list(dir := DIR) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in ids():
		var envelope := SaveGame.read_envelope(path_for(slot, dir))
		var data: Dictionary = envelope.get("data", {})
		result.append({
			"slot": slot,
			"empty": envelope.is_empty(),
			"saved_at": int(envelope.get("saved_at", 0)),
			"area": data.get("current_area", ""),
		})
	return result
