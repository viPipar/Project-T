# combat_core/_mock/MockStatProvider.gd
# Stub untuk mensimulasikan Candra's Stat System / StatsComponent
# Saat integrasi: ganti referensi MockStatProvider dengan StatsComponent milik entity
#
# Interface yang harus diimplementasikan oleh StatSystem nyata:
#   get_armor(entity)  -> int
#   get_resist(entity) -> int
#   get_acc(entity)    -> int
#   get_lck(entity)    -> int
#   get_mov(entity)    -> int
#   get_att(entity)    -> int
#   get_dex(entity)    -> int
#   get_int_stat(entity) -> int
#   get_str_stat(entity) -> int
#   get_max_hp(entity) -> int
class_name MockStatProvider
extends Node

# ── CATATAN INTEGRASI ─────────────────────────────────────────────────────────
# Saat Candra's StatsComponent sudah tersedia, ganti fungsi-fungsi ini dengan:
#   func get_armor(entity: Node) -> int:
#       var sc := entity.get_node_or_null("StatsComponent") as StatsComponent
#       if sc: return 10 + sc.bonus_armor()
#       return 10
# ─────────────────────────────────────────────────────────────────────────────

## Nilai default untuk testing — ubah sesuai kebutuhan test case kamu
@export var mock_armor   : int = 12
@export var mock_resist  : int = 8
@export var mock_acc     : int = 10
@export var mock_lck     : int = 5
@export var mock_mov     : int = 6
@export var mock_att     : int = 10
@export var mock_dex     : int = 8
@export var mock_int_val : int = 10
@export var mock_str_val : int = 10
@export var mock_vit     : int = 10
@export var mock_con     : int = 10


# Coba baca dari StatsComponent nyata dulu, fallback ke mock value
func get_armor(entity: Node) -> int:
	var sc := _get_stats(entity)
	if sc: return sc.get_armor()
	return mock_armor

func get_resist(entity: Node) -> int:
	var sc := _get_stats(entity)
	if sc: return sc.get_resist()
	return mock_resist

func get_acc(entity: Node) -> int:
	var sc := _get_stats(entity)
	if sc: return sc.get_stat("acc")
	return mock_acc

func get_lck(entity: Node) -> int:
	var sc := _get_stats(entity)
	if sc: return sc.get_stat("lck")
	return mock_lck

func get_mov(entity: Node) -> int:
	var sc := _get_stats(entity)
	if sc: return sc.get_stat("mov")
	return mock_mov

func get_att(entity: Node) -> int:
	var sc := _get_stats(entity)
	if sc: return sc.get_stat("att")
	return mock_att

func get_dex(entity: Node) -> int:
	var sc := _get_stats(entity)
	if sc: return sc.get_stat("dex")
	var ent_dex = entity.get("mock_dex")
	if ent_dex != null: return int(ent_dex)
	return mock_dex

func get_int_stat(entity: Node) -> int:
	var sc := _get_stats(entity)
	if sc: return sc.get_stat("int")
	return mock_int_val

func get_str_stat(entity: Node) -> int:
	var sc := _get_stats(entity)
	if sc: return sc.get_stat("str")
	return mock_str_val

func get_max_hp(entity: Node) -> int:
	var sc := _get_stats(entity)
	if sc: return sc.get_max_hp()
	return 15 + floori(mock_vit / 2.0) + floori(mock_str_val / 4.0)


# Helper internal
func _get_stats(entity: Node) -> StatsComponent:
	if entity == null:
		return null
	return entity.get_node_or_null("StatsComponent") as StatsComponent
