extends Node

# Dictionary to hold the loaded AudioStream resources
var sound_effects: Dictionary = {}
var bgm_tracks: Dictionary = {}

# Audio Players
var bgm_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var pool_size: int = 16
var current_pool_idx: int = 0
var last_wallet_balances: Dictionary = {1: -1, 2: -1}

# Definitions of file paths to load
const SFX_PATHS = {
	"ui_hover": "res://assets/sfx_packs/JDSherbert - Ultimate UI SFX Pack (FREE)/Stereo/ogg/JDSherbert - Ultimate UI SFX Pack - Cursor - 1.ogg",
	"ui_click": "res://assets/sfx_packs/JDSherbert - Ultimate UI SFX Pack (FREE)/Stereo/ogg/JDSherbert - Ultimate UI SFX Pack - Select - 1.ogg",
	"ui_cancel": "res://assets/sfx_packs/JDSherbert - Ultimate UI SFX Pack (FREE)/Stereo/ogg/JDSherbert - Ultimate UI SFX Pack - Cancel - 1.ogg",
	"ui_open": "res://assets/sfx_packs/JDSherbert - Ultimate UI SFX Pack (FREE)/Stereo/ogg/JDSherbert - Ultimate UI SFX Pack - Popup Open - 1.ogg",
	"ui_error": "res://assets/sfx_packs/JDSherbert - Ultimate UI SFX Pack (FREE)/Stereo/ogg/JDSherbert - Ultimate UI SFX Pack - Error - 1.ogg",
	"footstep_dirt_1": "res://assets/sfx_packs/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Footsteps/Dirt/Dirt Walk 1.ogg",
	"footstep_dirt_2": "res://assets/sfx_packs/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Footsteps/Dirt/Dirt Walk 2.ogg",
	"footstep_dirt_3": "res://assets/sfx_packs/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Footsteps/Dirt/Dirt Walk 3.ogg",
	"footstep_dirt_4": "res://assets/sfx_packs/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Footsteps/Dirt/Dirt Walk 4.ogg",
	"footstep_dirt_5": "res://assets/sfx_packs/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Footsteps/Dirt/Dirt Walk 5.ogg",
	"sword_miss": "res://assets/sfx_packs/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Attacks/Sword Attacks Hits and Blocks/Sword Attack 1.ogg",
	"sword_hit": "res://assets/sfx_packs/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Attacks/Sword Attacks Hits and Blocks/Sword Impact Hit 1.ogg",
	"spell_fire": "res://assets/sfx_packs/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Spells/Fireball 1.ogg",
	"spell_water": "res://assets/sfx_packs/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Spells/Waterspray 1.ogg",
	"spell_earth": "res://assets/sfx_packs/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Spells/Rock Meteor Throw 1.ogg",
	"spell_impact": "res://assets/sfx_packs/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Spells/Spell Impact 1.ogg",
	"spell_combo": "res://assets/sfx_packs/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Spells/Rock Meteor Swarm 1.ogg",
	"dice_roll": "res://assets/sfx_packs/400 Sound Packs/Musical Effects/8_bit_chime_quick.wav",
	"victory": "res://assets/sfx_packs/400 Sound Packs/Musical Effects/grand_piano_level_complete.wav",
	"defeat": "res://assets/sfx_packs/400 Sound Packs/Musical Effects/grand_piano_defeated.wav",
	"reveal_common": "res://assets/sfx_packs/400 Sound Packs/Musical Effects/8_bit_chime_positive.wav",
	"reveal_rare": "res://assets/sfx_packs/400 Sound Packs/Musical Effects/brass_chime_positive.wav",
	"reveal_legendary": "res://assets/sfx_packs/400 Sound Packs/Musical Effects/grand_piano_positive_long.wav",
	"coin_gain": "res://assets/sfx_packs/400 Sound Packs/Items/coin_collect.wav",
	"coin_spend": "res://assets/sfx_packs/400 Sound Packs/Items/coin_jingle_small.wav",
	"dice_bounce": "res://assets/sfx_packs/400 Sound Packs/Materials/wood_small_hollow.wav",
	"text_pop": "res://assets/sfx_packs/400 Sound Packs/UI/pop_1.wav",
	"text_pop_crit": "res://assets/sfx_packs/400 Sound Packs/UI/pop_3.wav",
	"clash_impact": "res://assets/sfx_packs/400 Sound Packs/Materials/metal_clang.wav",
	"number_absorb": "res://assets/sfx_packs/400 Sound Packs/Materials/glass_ping_small.wav",
	"result_hit": "res://assets/sfx_packs/400 Sound Packs/UI/sci_fi_confirm.wav",
	"result_miss": "res://assets/sfx_packs/400 Sound Packs/UI/sci_fi_error.wav",
	"result_crit": "res://assets/sfx_packs/400 Sound Packs/UI/sci_fi_select_big.wav",
	"damage_total_slam": "res://assets/sfx_packs/400 Sound Packs/Musical Effects/brass_chime_quick.wav",
	"grunt_female_1": "res://assets/sfx_packs/Super Dialogue Audio Pack v1/Step 2 - Audio Files/7 - Damage/Female/Karen Cenon/damage_1_karen.wav",
	"grunt_female_2": "res://assets/sfx_packs/Super Dialogue Audio Pack v1/Step 2 - Audio Files/7 - Damage/Female/Karen Cenon/damage_2_karen.wav",
	"grunt_female_3": "res://assets/sfx_packs/Super Dialogue Audio Pack v1/Step 2 - Audio Files/7 - Damage/Female/Karen Cenon/damage_3_karen.wav",
	"grunt_male_1": "res://assets/sfx_packs/Super Dialogue Audio Pack v1/Step 2 - Audio Files/7 - Damage/Male/Sean Lenhart/damage_1_sean.wav",
	"grunt_male_2": "res://assets/sfx_packs/Super Dialogue Audio Pack v1/Step 2 - Audio Files/7 - Damage/Male/Sean Lenhart/damage_2_sean.wav",
	"grunt_male_3": "res://assets/sfx_packs/Super Dialogue Audio Pack v1/Step 2 - Audio Files/7 - Damage/Male/Sean Lenhart/damage_3_sean.wav",
	"death_female_1": "res://assets/sfx_packs/Super Dialogue Audio Pack v1/Step 2 - Audio Files/8 - Death/Female/Karen Cenon/death_1_karen.wav",
	"death_female_2": "res://assets/sfx_packs/Super Dialogue Audio Pack v1/Step 2 - Audio Files/8 - Death/Female/Karen Cenon/death_2_karen.wav",
	"death_male_1": "res://assets/sfx_packs/Super Dialogue Audio Pack v1/Step 2 - Audio Files/8 - Death/Male/Sean Lenhart/death_1_sean.wav",
	"death_male_2": "res://assets/sfx_packs/Super Dialogue Audio Pack v1/Step 2 - Audio Files/8 - Death/Male/Sean Lenhart/death_2_sean.wav"
}

const BGM_PATHS = {
	"victory": "res://assets/music/Victory.mp3",
	"death_track": "res://assets/music/Death.mp3",
	"complete": "res://assets/music/Complete.mp3",
	"strange": "res://assets/music/Strange.mp3"
}

var ambient_tracks: Array[String] = []
var action_tracks: Array[String] = []
var light_ambient_tracks: Array[String] = []
var night_ambient_tracks: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	add_child(bgm_player)

	for i in range(pool_size):
		var p = AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		add_child(p)
		sfx_pool.append(p)

	_load_resources()
	_connect_event_bus()

	get_tree().node_added.connect(_on_node_added)
	_hook_existing_buttons(get_tree().root)

	play_random_ambient()

func _load_resources() -> void:
	for key in SFX_PATHS.keys():
		var path = SFX_PATHS[key]
		if ResourceLoader.exists(path):
			sound_effects[key] = load(path)
		else:
			push_warning("[AudioManager] SFX path not found: %s" % path)

	for key in BGM_PATHS.keys():
		var path = BGM_PATHS[key]
		if ResourceLoader.exists(path):
			bgm_tracks[key] = load(path)
		else:
			push_warning("[AudioManager] BGM path not found: %s" % path)

	for i in range(1, 11):
		var name_str = "Ambient %d.mp3" % i
		if i == 10:
			name_str = "Ambient 10 .mp3"
		var path = "res://assets/music/" + name_str
		if ResourceLoader.exists(path):
			var key = "ambient_%d" % i
			bgm_tracks[key] = load(path)
			ambient_tracks.append(key)
	for i in range(1, 6):
		var path = "res://assets/music/Light Ambient %d (Loop).mp3" % i
		if ResourceLoader.exists(path):
			var key = "light_ambient_%d" % i
			bgm_tracks[key] = load(path)
			light_ambient_tracks.append(key)
	for i in range(1, 6):
		var suffix = ".mp3" if i == 1 else " (Loop).mp3"
		var path = "res://assets/music/Night Ambient %d%s" % [i, suffix]
		if ResourceLoader.exists(path):
			var key = "night_ambient_%d" % i
			bgm_tracks[key] = load(path)
			night_ambient_tracks.append(key)
	for i in range(1, 6):
		var path = "res://assets/music/Action %d (Loop).mp3" % i
		if ResourceLoader.exists(path):
			var key = "action_%d" % i
			bgm_tracks[key] = load(path)
			action_tracks.append(key)

func play_sfx(sound_name: String) -> void:
	if not sound_effects.has(sound_name):
		push_warning("[AudioManager] SFX key not found: %s" % sound_name)
		return
		
	var stream = sound_effects[sound_name]
	if stream == null:
		return
		
	# Find a player that is not playing, or use the round-robin index
	var player = sfx_pool[current_pool_idx]
	for p in sfx_pool:
		if not p.playing:
			player = p
			break
			
	if player == sfx_pool[current_pool_idx]:
		current_pool_idx = (current_pool_idx + 1) % pool_size
		
	player.stream = stream
	player.play()

func play_bgm(track_name: String, fade_sec: float = 0.5) -> void:
	if not bgm_tracks.has(track_name):
		push_warning("[AudioManager] BGM track not found: %s" % track_name)
		return
		
	var stream = bgm_tracks[track_name]
	if stream == null:
		return
		
	if stream is AudioStreamMP3:
		stream.loop = true
		stream.loop_offset = 0.0
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
		stream.loop_offset = 0.0
	elif stream.has_method("set_loop_mode"):
		stream.set_loop_mode(1)
	elif "loop_mode" in stream:
		stream.set("loop_mode", 1)
	elif "loop" in stream:
		stream.set("loop", true)
		
	if bgm_player.playing and bgm_player.stream == stream:
		return # Already playing this track
		
	if fade_sec > 0 and bgm_player.playing:
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", -80.0, fade_sec)
		tween.tween_callback(func():
			bgm_player.stream = stream
			bgm_player.volume_db = 0.0
			bgm_player.play()
		)
	else:
		bgm_player.stream = stream
		bgm_player.volume_db = 0.0
		bgm_player.play()

func play_random_ambient() -> void:
	var pool = ambient_tracks + light_ambient_tracks + night_ambient_tracks
	if pool.is_empty():
		push_warning("[AudioManager] No ambient tracks loaded")
		return
	var key = pool[randi() % pool.size()]
	play_bgm(key)


func play_random_action() -> void:
	if action_tracks.is_empty():
		push_warning("[AudioManager] No action tracks loaded")
		return
	var key = action_tracks[randi() % action_tracks.size()]
	play_bgm(key)


func stop_bgm(fade_sec: float = 0.5) -> void:
	if fade_sec > 0 and bgm_player.playing:
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", -80.0, fade_sec)
		tween.tween_callback(func():
			bgm_player.stop()
			bgm_player.volume_db = 0.0
		)
	else:
		bgm_player.stop()

# --- EventBus Signal Hooks ---
func _connect_event_bus() -> void:
	var ev = get_node_or_null("/root/EventBus")
	if ev == null:
		push_warning("[AudioManager] EventBus autoload not found!")
		return
		
	# Combat flow
	if ev.has_signal("combat_started"):
		ev.connect("combat_started", _on_combat_started)
	if ev.has_signal("combat_ended"):
		ev.connect("combat_ended", _on_combat_ended)
	if ev.has_signal("player_moved"):
		ev.connect("player_moved", _on_player_moved)
	if ev.has_signal("damage_dealt"):
		ev.connect("damage_dealt", _on_damage_dealt)
	if ev.has_signal("entity_died"):
		ev.connect("entity_died", _on_entity_died)
	if ev.has_signal("entity_downed"):
		ev.connect("entity_downed", _on_entity_downed)
	if ev.has_signal("dice_rolled"):
		ev.connect("dice_rolled", _on_dice_rolled)
	if ev.has_signal("on_hit"):
		ev.connect("on_hit", _on_hit)
	if ev.has_signal("on_miss"):
		ev.connect("on_miss", _on_miss)
	if ev.has_signal("on_status_applied"):
		ev.connect("on_status_applied", _on_status_applied)
	if ev.has_signal("elemental_combo_triggered"):
		ev.connect("elemental_combo_triggered", _on_elemental_combo_triggered)
	if ev.has_signal("item_revealed"):
		ev.connect("item_revealed", _on_item_revealed)
	if ev.has_signal("contested_pick_started"):
		ev.connect("contested_pick_started", _on_contested_pick_started)
	if ev.has_signal("contested_pick_resolved"):
		ev.connect("contested_pick_resolved", _on_contested_pick_resolved)
	if ev.has_signal("action_wheel_selected"):
		ev.connect("action_wheel_selected", _on_action_wheel_selected)
	if ev.has_signal("action_wheel_visibility_changed"):
		ev.connect("action_wheel_visibility_changed", _on_action_wheel_visibility_changed)
		
	# Coin economy flow
	var coin_econ = get_node_or_null("/root/CoinEconomy")
	if coin_econ != null:
		coin_econ.balance_changed.connect(_on_coin_balance_changed)

func _on_combat_started(_combatants: Array) -> void:
	play_random_action()

func _on_combat_ended(result: String) -> void:
	if result.to_lower() == "victory":
		play_sfx("victory")
	else:
		play_sfx("defeat")
	get_tree().create_timer(4.0).timeout.connect(func(): play_random_ambient())

func _on_player_moved(_entity: Node, _from: Vector2i, _to: Vector2i) -> void:
	# Random dirt footstep sound
	var rand_idx = randi() % 5 + 1
	play_sfx("footstep_dirt_%d" % rand_idx)

func _on_damage_dealt(target: Node, _amount: int, _type: String, _is_crit: bool, _source: Node) -> void:
	# Play voice damage grunt based on target name
	var target_name = target.name.to_lower()
	if "aria" in target_name:
		var rand_grunt = randi() % 3 + 1
		play_sfx("grunt_female_%d" % rand_grunt)
	elif "kael" in target_name:
		var rand_grunt = randi() % 3 + 1
		play_sfx("grunt_male_%d" % rand_grunt)
	else:
		var rand_grunt = randi() % 3 + 1
		if randf() > 0.5:
			play_sfx("grunt_male_%d" % rand_grunt)
		else:
			play_sfx("grunt_female_%d" % rand_grunt)

func _on_entity_died(entity: Node, _killer: Node) -> void:
	var entity_name = entity.name.to_lower()
	if "aria" in entity_name:
		play_sfx("death_female_%d" % (randi() % 2 + 1))
	elif "kael" in entity_name:
		play_sfx("death_male_%d" % (randi() % 2 + 1))
	else:
		if randf() > 0.5:
			play_sfx("death_male_%d" % (randi() % 2 + 1))
		else:
			play_sfx("death_female_%d" % (randi() % 2 + 1))

func _on_entity_downed(entity: Node, _attacker: Node) -> void:
	var entity_name = entity.name.to_lower()
	if "aria" in entity_name:
		play_sfx("death_female_1")
	else:
		play_sfx("death_male_1")

func _on_dice_rolled(_player_id: int, _natural: int, _total: int, _vs_ac: int, _is_hit: bool, _is_crit: bool) -> void:
	play_sfx("dice_roll")

func _on_hit(_attacker: Node, _target: Node, result: Dictionary) -> void:
	var element = result.get("element_tag", "physical").to_lower()
	match element:
		"fire":
			play_sfx("spell_fire")
		"water":
			play_sfx("spell_water")
		"earth":
			play_sfx("spell_earth")
		_:
			play_sfx("sword_hit")
	play_sfx("spell_impact")

func _on_miss(_attacker: Node, _target: Node) -> void:
	play_sfx("sword_miss")

func _on_status_applied(_entity: Node, _status_id: String, _duration: int, _stacks: int) -> void:
	play_sfx("reveal_common")

func _on_elemental_combo_triggered(_target: Node, _combo_name: String, _combo_effect: String) -> void:
	play_sfx("spell_combo")

func _on_item_revealed(rarity: int) -> void:
	match rarity:
		1: # Rare / Blue
			play_sfx("reveal_rare")
		2: # Legendary / Gold
			play_sfx("reveal_legendary")
		_: # Common / White
			play_sfx("reveal_common")

func _on_contested_pick_started(_item_data: Variant, _p1_roll: int, _p2_roll: int) -> void:
	play_sfx("dice_roll")

func _on_contested_pick_resolved(_winner_id: int, _item_data: Variant) -> void:
	play_sfx("reveal_rare")

# --- UI Button Global Hooking ---
func _on_node_added(node: Node) -> void:
	_hook_button(node)

func _hook_existing_buttons(node: Node) -> void:
	_hook_button(node)
	for child in node.get_children():
		_hook_existing_buttons(child)

func _hook_button(node: Node) -> void:
	if node is Button:
		if not node.pressed.is_connected(_on_button_pressed):
			node.pressed.connect(_on_button_pressed.bind(node))
		if not node.mouse_entered.is_connected(_on_button_hover):
			node.mouse_entered.connect(_on_button_hover)
		if not node.focus_entered.is_connected(_on_button_hover):
			node.focus_entered.connect(_on_button_hover)

func _on_button_pressed(btn: Button) -> void:
	var btn_name = btn.name.to_lower()
	if "cancel" in btn_name or "close" in btn_name or "back" in btn_name:
		play_sfx("ui_cancel")
	else:
		play_sfx("ui_click")

func _on_button_hover() -> void:
	play_sfx("ui_hover")

func _on_coin_balance_changed(player_id: int, new_balance: int) -> void:
	if not last_wallet_balances.has(player_id):
		last_wallet_balances[player_id] = new_balance
		return
		
	var old_balance = last_wallet_balances[player_id]
	last_wallet_balances[player_id] = new_balance
	
	if old_balance == -1:
		return
		
	if new_balance > old_balance:
		play_sfx("coin_gain")
	elif new_balance < old_balance:
		play_sfx("coin_spend")

func _on_action_wheel_selected(_player_id: int, _action_name: String) -> void:
	play_sfx("ui_click")

func _on_action_wheel_visibility_changed(_player_id: int, is_visible: bool) -> void:
	if is_visible:
		play_sfx("ui_open")
	else:
		play_sfx("ui_cancel")
