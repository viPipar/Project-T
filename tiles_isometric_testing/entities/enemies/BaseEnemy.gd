extends CharacterBody2D

# ─────────────────────────────────────────────
#  BaseEnemy
#  Semua enemy turunan dari node ini.
#  Komponen ditambahkan sebagai child di scene editor.
#  EnemyData resource mengisi semua stats sekaligus.
#
#  Scene hierarchy:
#    BaseEnemy (CharacterBody2D)
#    ├── Sprite2D / AnimatedSprite2D
#    ├── HealthComponent
#    ├── StatsComponent
#    ├── MovementComponent
#    ├── CombatComponent
#    ├── ConditionComponent
#    └── AIComponent
# ─────────────────────────────────────────────

@export var enemy_data: Resource   # EnemyData resource

var grid_pos:  Vector2i = Vector2i.ZERO
var char_name: String   = "Enemy"

# Komponen — gunakan get_node_or_null di _ready agar tidak crash
# kalau scene belum punya semua child
@onready var health:    HealthComponent    = $HealthComponent
@onready var stats:     StatsComponent     = $StatsComponent
@onready var movement:  MovementComponent  = $MovementComponent
@onready var combat:    CombatComponent    = $CombatComponent
@onready var cond:      ConditionComponent = $ConditionComponent
@onready var ai:        AIComponent        = $AIComponent


func _ready() -> void:
	add_to_group("enemies")
	_apply_data()
	health.died.connect(_on_died)


# ── Data Application ──────────────────────────

func _apply_data() -> void:
	if enemy_data == null:
		return

	char_name              = enemy_data.enemy_name

	health.max_hp          = enemy_data.max_hp
	health.current_hp      = enemy_data.max_hp

	stats.strength         = enemy_data.strength
	stats.dexterity        = enemy_data.dexterity
	stats.constitution     = enemy_data.constitution
	stats.intelligence     = enemy_data.intelligence
	stats.wisdom           = enemy_data.wisdom
	stats.charisma         = enemy_data.charisma
	stats.base_armor_class = enemy_data.base_armor_class

	movement.base_movement = enemy_data.movement_speed
	movement.movement_left = enemy_data.movement_speed

	combat.attack_dice     = enemy_data.attack_dice
	combat.attack_range    = enemy_data.attack_range

	ai.behavior            = enemy_data.ai_behavior
	ai.detection_range     = enemy_data.detection_range
	ai.preferred_range     = enemy_data.attack_range


# ── Grid Positioning ──────────────────────────

func get_grid_pos() -> Vector2i:
	return grid_pos


func place_at(pos: Vector2i) -> void:
	if grid_pos != Vector2i.ZERO:
		GridManager.unregister_entity(grid_pos)
	grid_pos  = pos
	GridManager.register_entity(pos, self)
	position  = IsoUtils.world_to_iso(pos)
	z_index   = IsoUtils.get_depth(pos)


# ── Death ─────────────────────────────────────

func _on_died(_killer: Node) -> void:
	# Lepas dari grid segera
	GridManager.unregister_entity(grid_pos)
	# Animasi mati (jika ada), lalu hapus
	set_process(false)
	await get_tree().create_timer(0.6).timeout
	queue_free()
