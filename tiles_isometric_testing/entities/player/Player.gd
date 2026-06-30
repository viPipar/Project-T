# entities/player/Player.gd
# Tanggung jawab:
#   Mengelola input, animasi, posisi grid, dan API health dasar milik player.
#
# Cara pakai:
#   var player := preload("res://entities/player/Player.tscn").instantiate()
#   player.place_at(Vector2i(5, 7))
#   player.take_damage(4, enemy)
#
# Cara evaluasi:
#   1. Jalankan Main.tscn.
#   2. Tekan F1/checkbox debug stats dan serang enemy.
#   3. Pastikan posisi grid tidak dobel dan HP player berubah saat terkena damage.
extends CharacterBody2D

# ─────────────────────────────────────────────────────────────────────────────
#  Player
#
#  Owns animation + input reading. Movement logic lives entirely in
#  MovementComponent — this script only calls move_to() / interact_move_to()
#  and reacts to the component's signals.
# ─────────────────────────────────────────────────────────────────────────────

@export var player_id:  int    = 1
@export var char_name:  String = "Player"
@onready var sprite_p1:  AnimatedSprite2D  = $Player1Sprite
@onready var sprite_p2:  AnimatedSprite2D  = $Player2Sprite
@onready var movement:   MovementComponent = $MovementComponent
@onready var stats:      StatsComponent    = $StatsComponent
@onready var class_comp: ClassComponent    = $ClassComponent
@onready var health:     HealthComponent   = $HealthComponent
@onready var cond:       ConditionComponent = $ConditionComponent

var anim_sprite: AnimatedSprite2D
var _is_acting: bool = false

var _facing:  String   = "down"
var grid_pos: Vector2i = Vector2i.ZERO
var _cursor:  Node2D   = null
var selected_ability_id: String = "main_attack"
var _loaded_ability: BaseAbility = null
var _targeting_tiles: Array[Vector2i] = []
var _haki_aura: Node2D = null

enum PlayerState { IDLE, TARGETING, ACTING }
var _state: PlayerState = PlayerState.IDLE
# Tidak ada _combat_blocked lokal — InputManager.set_player_blocked() yang handle

const INSECT1_DIR := "res://assets/characters/insect1_placeholder"
const INSECT2_DIR := "res://assets/characters/insect2_placeholder"


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("players")
	_setup_sprite()
	# _apply_idle_frames() # Commented out to use custom editor-configured SpriteFrames
	_play_facing_anim()

	movement.move_finished.connect(_on_move_finished)
	movement.step_started.connect(_on_step_started)
	if health != null and not health.died.is_connected(_on_died):
		health.died.connect(_on_died)
	if health != null and not health.downed.is_connected(_on_downed):
		health.downed.connect(_on_downed)
	if health != null and not health.revived.is_connected(_on_revived):
		health.revived.connect(_on_revived)

	# Subscribe ke sinyal blok input dari CombatTestBridge via EventBus
	EventBus.combat_input_blocked.connect(_on_combat_input_blocked)
	EventBus.action_wheel_selected.connect(_on_action_wheel_selected)

	# Subscribe ke sinyal damaged dari HealthComponent untuk animasi hit
	if health != null and not health.damaged.is_connected(_on_damaged):
		health.damaged.connect(_on_damaged)


func _process(_delta: float) -> void:
	if is_downed():
		_play_facing_anim()
		_apply_facing_flip()
		return

	# Update facing from cursor hover, but only when not mid-travel
	if not movement._is_moving and _cursor != null and _cursor.has_method("get_hovered_tile"):
		var hovered: Vector2i = _cursor.get_hovered_tile()
		if hovered.x >= 0:
			_update_facing_from_to(grid_pos, hovered)

	_play_facing_anim()
	_apply_facing_flip()
	
	# ── CANCEL KEY ─────────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("p%d_cancel" % player_id):
		if _state == PlayerState.TARGETING:
			_exit_targeting()
			EventBus.resource_blink_requested.emit(player_id, "stop_all")
			return

	# ── END TURN ──────────────────────────────────────────────────────────────
	if InputManager.is_end_turn_pressed(player_id):
		if TurnManager != null and TurnManager.is_player_ended(player_id):
			TurnManager.cancel_end_turn(player_id)
		elif not movement._is_moving:
			if TurnManager != null:
				TurnManager.request_end_turn(player_id)
		return

	# ── CONFIRM KEY ────────────────────────────────────────────────────────────
	if InputManager.is_confirm_pressed(player_id):
		if _state == PlayerState.TARGETING:
			_on_targeting_confirm()
		else:
			_on_confirm()


# ── Input Handler ────────────────────────────────────────────────────────────

func _on_confirm() -> void:
	if movement._is_moving:
		return  # don't queue new move while animating
	# Blok dicek via InputManager (is_confirm_pressed sudah cek _player_blocked di sana)

	var target: Vector2i = Vector2i(-1, -1)
	if is_instance_valid(_cursor) and _cursor.has_method("get_hovered_tile"):
		target = _cursor.get_hovered_tile()
	if target.x < 0:
		return
	_update_facing_from_to(grid_pos, target)

	var occupant := GridManager.get_entity_at(target)
	var entity_type := GridManager.get_entity_type(target)
	var walkable := GridManager.is_walkable(target)

	if occupant != null:
		match entity_type:
			GridManager.EntityType.ENEMY:
				print("[Player P%d] Pilih ability dari action wheel dulu sebelum menyerang." % player_id)
				return

			GridManager.EntityType.NPC:
				print("Player ", player_id, " bicara dengan NPC: ", occupant.name)
				# TODO: tampilkan dialog NPC

			GridManager.EntityType.PLAYER:
				print("[Player P%d] Target player butuh ability/revive flow, bukan direct confirm." % player_id)
				return
				# TODO: co-op / pass turn
	elif not walkable:
		movement.interact_move_to(target)
	else:
		movement.move_to(target)

# ── Signal Callbacks ──────────────────────────────────────────────────────────

func _on_move_finished(from: Vector2i, to: Vector2i) -> void:
	_update_facing_from_to(from, to)


func _on_step_started(from: Vector2i, to: Vector2i) -> void:
	_update_facing_from_to(from, to)


func _on_action_wheel_selected(pid: int, action_name: String) -> void:
	if pid != player_id:
		return
	if is_downed():
		EventBus.resource_blink_requested.emit(player_id, "stop_all")
		return

	var raw_id = action_name.to_lower().replace(" ", "_")
	# Map generic UI actions to our .tres physical/magical abilities
	if player_id == 1:
		# Fighter / Warrior
		match raw_id:
			"attack": raw_id = "main_attack"
			"skill": raw_id = "slash_flash"
			"guard": raw_id = "autotomy"
			"item": raw_id = "cleave"
			"reload": raw_id = "divine_departure"
	elif player_id == 2:
		# Mage / Wizard
		match raw_id:
			"attack": raw_id = "staff_bonk"
			"skill": raw_id = "fireball"
			"guard": raw_id = "water_blast"
			"item": raw_id = "earth_spike"
			"reload": raw_id = "gust_of_wind"

	selected_ability_id = raw_id
	print("[Player P%d] Ability terpilih: %s" % [player_id, selected_ability_id])

	# Load the .tres resource
	var path := "res://combat_core/abilities/instances/%s.tres" % selected_ability_id
	_loaded_ability = load(path) as BaseAbility
	if _loaded_ability == null:
		push_warning("[Player P%d] Ability resource '%s' tidak ditemukan!" % [player_id, path])
		return

	# Abilities that don't need manual target selection skip the cursor
	if not _loaded_ability.requires_target_selection():
		if _loaded_ability.is_untargeted_aoe:
			var tiles = _loaded_ability.get_target_tiles(grid_pos)
			var has_target := false
			for t in tiles:
				var ent = GridManager.get_entity_at(t)
				if ent != null and ent != self and ent.has_method("get_armor"):
					var pid_ent = ent.get("player_id")
					var pid_att = self.get("player_id")
					if (self.is_in_group("enemies") != ent.is_in_group("enemies")) or (pid_ent != null and pid_att != null and pid_ent != pid_att):
						has_target = true
						break
			
			if not has_target:
				print("[Player P%d] Tidak ada target di area AOE, membatalkan skill." % player_id)
				_loaded_ability = null
				return

		print("[Player P%d] Auto-targeting: %s — executing immediately" % [player_id, _loaded_ability.ability_name])
		_begin_action_resolution()
		EventBus.attackcam_started.emit(self, self, selected_ability_id, grid_pos)
		return

	# Enter targeting mode — show grid, hide wheel
	_enter_targeting()
	_emit_blink_for_ability(_loaded_ability)


func _emit_blink_for_ability(ability: BaseAbility) -> void:
	if ability == null: return
	if ability.cost_action > 0:
		EventBus.resource_blink_requested.emit(player_id, "ap")
	if ability.cost_bonus_action > 0:
		EventBus.resource_blink_requested.emit(player_id, "bap")
	if ability.cost_mana > 0:
		var res := "energy_charge" if player_id == 1 else "spell_slot"
		EventBus.resource_blink_requested.emit(player_id, res)
	# User wants movement to blink as well during targeting
	EventBus.resource_blink_requested.emit(player_id, "movement")


## Enter TARGETING state: show highlighted tiles, let cursor pick a target.
func _enter_targeting() -> void:
	_state = PlayerState.TARGETING
	_targeting_tiles = _loaded_ability.get_target_tiles(grid_pos)
	var highlight_type := _loaded_ability.get_highlight_type()
	HighlightManager.replace_tiles(_targeting_tiles, highlight_type, player_id)
	
	if is_instance_valid(MovementRangeManager) and MovementRangeManager.has_method("_refresh_player"):
		MovementRangeManager._refresh_player(self)
		
	print("[Player P%d] TARGETING mode — %d tiles highlighted" % [player_id, _targeting_tiles.size()])


## Exit TARGETING state: clear highlights, return to idle.
func _exit_targeting() -> void:
	_state = PlayerState.IDLE
	_clear_targeting_highlights()
	_targeting_tiles.clear()
	_loaded_ability = null
	
	if is_instance_valid(MovementRangeManager) and MovementRangeManager.has_method("_refresh_player"):
		MovementRangeManager._refresh_player(self)
		
	EventBus.resource_blink_requested.emit(player_id, "stop_all")
	print("[Player P%d] Targeting CANCELLED" % player_id)


## Confirm target selection during TARGETING state.
func _on_targeting_confirm() -> void:
	if _cursor == null or not _cursor.has_method("get_hovered_tile"):
		return

	var target_tile: Vector2i = _cursor.get_hovered_tile()
	if target_tile.x < 0:
		return

	# Check if the cursor is on a valid highlighted tile
	if target_tile not in _targeting_tiles:
		print("[Player P%d] Target tile %s is NOT in range!" % [player_id, target_tile])
		return

	# Check if there's an entity to hit on that tile
	var occupant := GridManager.get_entity_at(target_tile)
	if occupant == null:
		if _can_target_empty_tile():
			print("[Player P%d] TARGET TILE CONFIRMED: %s at %s" % [player_id, _loaded_ability.ability_name, target_tile])
			EventBus.resource_blink_requested.emit(player_id, "stop_all")
			if EventBus != null:
				EventBus.ability_executed.emit(self, [], {
					"ability_id": selected_ability_id,
					"target_tile": target_tile,
					"is_empty_tile": true,
				})
			_finish_action_resolution()
			return
		print("[Player P%d] No target entity at tile %s" % [player_id, target_tile])
		return

	print("[Player P%d] TARGET CONFIRMED: %s → %s" % [player_id, _loaded_ability.ability_name, occupant.name])

	# Fire the ability
	_update_facing_from_to(grid_pos, target_tile)
	_begin_action_resolution()
	EventBus.attackcam_started.emit(self, occupant, selected_ability_id, target_tile)
	EventBus.resource_blink_requested.emit(player_id, "stop_all")
	if player_id == 1:
		AttackCam.play(true, false)
	elif player_id == 2:
		AttackCam.play(false, true)

## Dipanggil saat combat_input_blocked signal diterima dari EventBus.
func _on_combat_input_blocked(blocked_player_id: int, blocked: bool) -> void:
	if blocked_player_id != player_id:
		return
	if blocked:
		if _state == PlayerState.TARGETING:
			_state = PlayerState.ACTING
		if is_instance_valid(MovementRangeManager) and MovementRangeManager.has_method("_refresh_player"):
			MovementRangeManager._refresh_player(self)
	elif _state == PlayerState.ACTING:
		_finish_action_resolution()


## Dipanggil saat player menerima damage dari HealthComponent.
func _on_damaged(_amount: int) -> void:
	_play_hurt_anim()


## Mainkan animasi 'hit' satu kali penuh lalu kembali ke idle.
func _play_hurt_anim() -> void:
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return
	var hurt_anim := "hit"
	if not anim_sprite.sprite_frames.has_animation(hurt_anim):
		return
	if _is_acting:
		return  # Jangan interrupt animasi attack
	_is_acting = true
	anim_sprite.sprite_frames.set_animation_loop(hurt_anim, false)
	anim_sprite.play(hurt_anim)
	await anim_sprite.animation_finished
	_is_acting = false
	_play_facing_anim()


# ── Public API ────────────────────────────────────────────────────────────────

func _begin_action_resolution() -> void:
	_state = PlayerState.ACTING
	if is_instance_valid(MovementRangeManager) and MovementRangeManager.has_method("_refresh_player"):
		MovementRangeManager._refresh_player(self)


func _finish_action_resolution() -> void:
	_clear_targeting_highlights()
	_targeting_tiles.clear()
	_loaded_ability = null
	_state = PlayerState.IDLE
	EventBus.resource_blink_requested.emit(player_id, "stop_all")
	if is_instance_valid(MovementRangeManager) and MovementRangeManager.has_method("_refresh_player"):
		MovementRangeManager._refresh_player(self)


func _clear_targeting_highlights() -> void:
	HighlightManager.clear("attack")
	HighlightManager.clear("skill")


func _can_target_empty_tile() -> bool:
	if _loaded_ability == null:
		return false
	return _loaded_ability.aoe_type != "none" or _loaded_ability.target_alignment == BaseAbility.TargetAlignment.ANY


func get_grid_pos() -> Vector2i:
	return grid_pos

func get_player_id() -> int:
	return player_id

func get_movement_left() -> int:
	if is_downed():
		return 0
	return movement.movement_left

func bind_cursor(cursor: Node2D) -> void:
	_cursor = cursor

func place_at(pos: Vector2i) -> void:
	if GridManager.get_entity_at(grid_pos) == self:
		GridManager.unregister_entity(grid_pos)

	grid_pos = pos
	GridManager.register_entity(pos, self, GridManager.EntityType.PLAYER)
	position = IsoUtils.world_to_iso(pos)
	z_index  = IsoUtils.get_depth(pos)


func take_damage(amount: int, attacker: Node = null, damage_type: String = "physical") -> int:
	if health == null:
		return 0
	return health.take_damage(amount, attacker, damage_type)


func heal(amount: int) -> int:
	if health == null:
		return 0
	return health.heal(amount, self)


func get_hp() -> int:
	return health.get_hp() if health != null else 0


func get_max_hp() -> int:
	return health.get_max_hp() if health != null else 0


func sub_hp(amount: int, attacker: Node = null, damage_type: String = "true") -> int:
	if health == null:
		return 0
	return health.sub_hp(amount, attacker, damage_type)


func add_hp(amount: int) -> int:
	if health == null:
		return 0
	return health.add_hp(amount)


func get_armor() -> int:
	return stats.get_armor() if stats != null else 0


func get_resist() -> int:
	return stats.get_resist() if stats != null else 0


func get_stat(stat_key: String) -> int:
	return stats.get_stat(stat_key) if stats != null else 0


func add_stat(stat_key: String, amount: int) -> bool:
	return stats.add_base_stat(stat_key, amount) if stats != null else false


func sub_stat(stat_key: String, amount: int) -> bool:
	return stats.sub_base_stat(stat_key, amount) if stats != null else false


func is_dead() -> bool:
	return health != null and health.is_dead()


func is_downed() -> bool:
	return health != null and health.is_downed()


func is_targeting_ability() -> bool:
	return _state == PlayerState.TARGETING


func is_resolving_action() -> bool:
	return _state == PlayerState.ACTING


func should_hide_movement_range() -> bool:
	if _state == PlayerState.TARGETING or _state == PlayerState.ACTING:
		return true
	if InputManager != null and InputManager.is_player_blocked(player_id):
		return true
	return false


func is_tile_valid_for_targeting(tile: Vector2i) -> bool:
	return _state == PlayerState.TARGETING and tile in _targeting_tiles


func can_target_empty_tile() -> bool:
	return _can_target_empty_tile()


# ── Internal ──────────────────────────────────────────────────────────────────

func _setup_sprite() -> void:
	if player_id == 1:
		sprite_p1.visible = true
		sprite_p2.visible = false
		anim_sprite = sprite_p1
	elif player_id == 2:
		sprite_p1.visible = false
		sprite_p2.visible = true
		anim_sprite = sprite_p2


func _apply_idle_frames() -> void:
	var dir_path := INSECT1_DIR if player_id == 1 else INSECT2_DIR
	var frames := _load_frames_from_dir(dir_path)
	if frames.is_empty():
		return

	var sprite_frames := SpriteFrames.new()
	var anims := ["idle_down", "idle_left", "idle_right", "idle_up"]

	for anim_name in anims:
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_speed(anim_name, 24.0)
		sprite_frames.set_animation_loop(anim_name, true)
		for tex in frames:
			sprite_frames.add_frame(anim_name, tex)

	anim_sprite.sprite_frames = sprite_frames


func _load_frames_from_dir(dir_path: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Player: tidak bisa buka folder sprite: %s" % dir_path)
		return result

	var files: Array[String] = []
	for f in dir.get_files():
		if f.to_lower().ends_with(".png"):
			files.append(f)
	files.sort()

	for f in files:
		var tex := load(dir_path + "/" + f) as Texture2D
		if tex != null:
			result.append(tex)
	return result


func _update_facing_from_to(from: Vector2i, to: Vector2i) -> void:
	if from == to:
		return
	var screen_from := IsoUtils.world_to_iso(from)
	var screen_to := IsoUtils.world_to_iso(to)
	var delta := screen_to - screen_from
	if abs(delta.x) >= abs(delta.y):
		_facing = "right" if delta.x > 0 else "left"
	else:
		_facing = "down" if delta.y > 0 else "up"


func _play_facing_anim() -> void:
	if _is_acting:
		return
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return
	
	var walk_anim := "walk_" + _facing
	var idle_anim := "idle_" + _facing
	var anim := "idle"
	
	if movement != null and movement._is_moving:
		if anim_sprite.sprite_frames.has_animation(walk_anim):
			anim = walk_anim
		elif anim_sprite.sprite_frames.has_animation("walk"):
			anim = "walk"
	else:
		if anim_sprite.sprite_frames.has_animation(idle_anim):
			anim = idle_anim
		elif anim_sprite.sprite_frames.has_animation("idle"):
			anim = "idle"
			
	anim_sprite.play(anim)


func _apply_facing_flip() -> void:
	if anim_sprite == null:
		return
	
	if player_id == 1:
		# Player 1 (Fighter) faces RIGHT by default in the spritesheet
		if _facing == "left":
			anim_sprite.flip_h = true
		elif _facing == "right":
			anim_sprite.flip_h = false
	else:
		# Player 2 (Wizard) faces LEFT by default in the spritesheet
		if _facing == "left":
			anim_sprite.flip_h = false
		elif _facing == "right":
			anim_sprite.flip_h = true


func _on_died(_killer: Node) -> void:
	print("[Player] %s kalah." % char_name)
	set_process(false)
	if anim_sprite != null:
		anim_sprite.modulate = Color(0.35, 0.35, 0.35, 0.6)


func _on_downed(_attacker: Node) -> void:
	print("[Player] %s downed." % char_name)
	if _state == PlayerState.TARGETING or _state == PlayerState.ACTING:
		_exit_targeting()
	if movement != null:
		movement.movement_left = 0
	EventBus.resource_blink_requested.emit(player_id, "stop_all")
	if anim_sprite != null:
		anim_sprite.modulate = Color(0.55, 0.55, 0.55, 0.85)


func _on_revived() -> void:
	print("[Player] %s revived." % char_name)
	if anim_sprite != null:
		anim_sprite.modulate = Color(1, 1, 1, 1)


func play_attack(ability_id: String) -> void:
	if is_downed():
		return
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return
	
	var anim_name := "attack_1"
	
	# List of skills that use attack_2
	var attack_2_skills := [
		"slash_flash", "cleave", "divine_departure", # Fighter
		"fireball", "earth_spike", "gust_of_wind"    # Wizard
	]
	
	if ability_id in attack_2_skills:
		anim_name = "attack_2"
		
	if anim_sprite.sprite_frames.has_animation(anim_name):
		_is_acting = true
		# Force loop to false for attack animations
		anim_sprite.sprite_frames.set_animation_loop(anim_name, false)
		anim_sprite.play(anim_name)
		
		# Await the animation finishing
		await anim_sprite.animation_finished
		
		# Jangan diblok di sini! Biarkan CombatTestBridge langsung apply damage.
		# Sisa getaran / follow-through dilakukan di background (async)
		_play_recovery_async(anim_name)
		
		# Return sekarang agar damage langsung masuk tepat saat animasi serang kelar!
		return

func _play_recovery_async(anim_name: String) -> void:
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		_is_acting = false
		_play_facing_anim()
		return

	# ── GABUNGAN JUICY IMPACT (Strain Loop + Heavy Hold) ──────────
	# Mensimulasikan momentum berlebih dan recovery dari heavy attack
	var total_frames := anim_sprite.sprite_frames.get_frame_count(anim_name)
	if total_frames >= 2:
		var last_f := total_frames - 1
		var prev_f := total_frames - 2
		
		# 1. Strain Loop (Bergetar cepat menahan senjata)
		for i in range(2):
			anim_sprite.frame = prev_f
			await get_tree().create_timer(0.06, false).timeout
			anim_sprite.frame = last_f
			await get_tree().create_timer(0.09, false).timeout
		
		# 2. Heavy Hold (Tahan posisi akhir sebelum relaks)
		await get_tree().create_timer(0.12, false).timeout
	else:
		# Fallback jika cuma 1 frame (Heavy Hold saja)
		await get_tree().create_timer(0.20, false).timeout
	# ─────────────────────────────────────────────────────────────

	_is_acting = false
	# Reset back to facing idle
	_play_facing_anim()


func activate_haki_aura() -> void:
	if _haki_aura == null:
		var haki_scene = load("res://components/haki/HakiAura.tscn")
		if haki_scene:
			_haki_aura = haki_scene.instantiate()
			add_child(_haki_aura)
			
	if is_instance_valid(_haki_aura) and _haki_aura.has_method("activate"):
		_haki_aura.activate(anim_sprite, player_id)


func deactivate_haki_aura() -> void:
	if is_instance_valid(_haki_aura) and _haki_aura.has_method("deactivate"):
		_haki_aura.deactivate()
