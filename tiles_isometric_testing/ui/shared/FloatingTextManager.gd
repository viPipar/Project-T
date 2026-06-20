# ui/shared/FloatingTextManager.gd
# ── Manager untuk floating combat text ───────────────────────────────────────
# Mendengarkan EventBus dan spawn FloatingDamageNumber di world-space.
# Node ini di-add ke Main scene dari main.gd.
#
# World-space spawn → otomatis terlihat di kedua SubViewport (shared World2D).
#
# Referensi signals yang dipakai:
#   EventBus.damage_dealt(target, amount, type, is_crit)
#   EventBus.floating_text_requested(entity, text, color, type)  [miss/heal/dll]
extends Node

const _SCENE_PATH := "res://ui/shared/FloatingDamageNumber.tscn"

var _scene : PackedScene = null
var _world_node : Node = null   # target parent untuk spawn (world tree)


func _ready() -> void:
	_scene = load(_SCENE_PATH)
	if _scene == null:
		push_error("[FloatingTextManager] FloatingDamageNumber.tscn tidak ditemukan di %s!" % _SCENE_PATH)
		return

	# Cari world node untuk jadi parent spawn
	# Harus ada di world tree agar terlihat di kedua SubViewport
	_world_node = get_tree().root

	# Koneksi ke EventBus
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		return
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.floating_text_requested.connect(_on_floating_text_requested)
	EventBus.on_miss.connect(_on_miss)

	print("[FloatingTextManager] Siap — floating damage numbers aktif ✅")


# ── EVENT HANDLERS ─────────────────────────────────────────────────────────────

func _on_damage_dealt(target: Node, amount: int, _dmg_type: String, is_crit: bool) -> void:
	if not is_instance_valid(target) or amount <= 0:
		return

	# Offset ke atas sprite, sedikit random agar tidak tumpuk
	var base_pos : Vector2 = target.global_position + Vector2(0, -48)
	var type_str  := "crit" if is_crit else "damage"
	_spawn_number(amount, type_str, base_pos)


func _on_miss(_attacker: Node, target: Node) -> void:
	if not is_instance_valid(target):
		return
	var base_pos : Vector2 = target.global_position + Vector2(0, -48)
	_spawn_miss(base_pos)


func _on_floating_text_requested(entity: Node, text: String, color: Color, type: String) -> void:
	if not is_instance_valid(entity):
		return
	var base_pos : Vector2 = entity.global_position + Vector2(0, -48)
	match type:
		"heal":
			# text berisi angka heal
			var amount := text.to_int()
			_spawn_number(amount, "heal", base_pos)
		"miss":
			_spawn_miss(base_pos)
		_:
			# Generic text — tampilkan sebagai damage dengan warna custom
			_spawn_generic(text, color, base_pos)


# ── SPAWN HELPERS ──────────────────────────────────────────────────────────────

func _spawn_number(amount: int, type: String, world_pos: Vector2) -> void:
	if _scene == null or _world_node == null:
		return
	var inst := _scene.instantiate() as FloatingDamageNumber
	_world_node.add_child(inst)
	inst.global_position = world_pos
	inst.display(amount, type)


func _spawn_miss(world_pos: Vector2) -> void:
	if _scene == null or _world_node == null:
		return
	var inst := _scene.instantiate() as FloatingDamageNumber
	_world_node.add_child(inst)
	inst.global_position = world_pos
	inst.display(0, "miss")


func _spawn_generic(text: String, _color: Color, world_pos: Vector2) -> void:
	# Fallback: tampilkan sebagai damage biasa
	if _scene == null or _world_node == null:
		return
	var amount := text.to_int() if text.is_valid_int() else 0
	_spawn_number(amount, "damage", world_pos)
