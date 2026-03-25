extends Node

# ── DATA CLASSES ─────────────────────────────────────────────

class AttackRollResult:
	var natural_roll: int
	var attack_total: int
	var target_ac: int
	var is_hit: bool
	var is_crit: bool
	var is_fumble: bool
	var damage: int
	var damage_dice: String
	var damage_rolls: Array[int]

class DamageRollResult:
	var total: int
	var rolls: Array[int]
	var formula: String
	var is_maximized: bool

# ── INITIALIZATION ───────────────────────────────────────────

func _ready() -> void:
	# Penting: Acak seed RNG setiap kali game dimulai
	randomize()

# ── CORE FUNCTIONS ───────────────────────────────────────────

## Mengocok 1 buah dadu dengan jumlah sisi tertentu (misal: d20 = roll_single(20))
func roll_single(sides: int) -> int:
	if sides < 1: return 0
	return randi_range(1, sides)

## Menerima string "2d6+3", lalu mengembalikan array hasil kocokan dadunya (tanpa bonus flat)
func parse_and_roll(formula: String) -> Array[int]:
	var results: Array[int] = []
	formula = formula.to_lower().replace(" ", "")
	
	# Pecah bagian bonus/penalty (misal "2d6+3" -> ["2d6", "3"])
	var parts = formula.split("+")
	var base_dice = parts[0]
	if "-" in base_dice:
		base_dice = base_dice.split("-")[0]
		
	# Pecah jumlah dadu dan sisi (misal "2d6" -> ["2", "6"])
	var dice_parts = base_dice.split("d")
	if dice_parts.size() != 2:
		return results # Format salah
		
	var num_dice: int = dice_parts[0].to_int()
	var sides: int = dice_parts[1].to_int()
	
	for i in range(num_dice):
		results.append(roll_single(sides))
		
	return results

## Menghitung hasil damage, termasuk jika critical (dadu dikali 2)
func roll_damage(formula: String, is_crit: bool = false) -> DamageRollResult:
	var result := DamageRollResult.new()
	result.formula = formula
	result.is_maximized = false
	result.rolls = []
	result.total = 0
	
	var flat_mod: int = 0
	formula = formula.to_lower().replace(" ", "")
	
	# Cari modifier flat (+ atau -)
	if "+" in formula:
		flat_mod = formula.split("+")[1].to_int()
	elif "-" in formula:
		flat_mod = -formula.split("-")[1].to_int()
		
	# Roll dadunya
	var dice_rolls = parse_and_roll(formula)
	
	# Kalau critical, jumlah dadu yang dilempar dikali 2
	if is_crit:
		var extra_rolls = parse_and_roll(formula)
		dice_rolls.append_array(extra_rolls)
		
	result.rolls = dice_rolls
	
	# Hitung total
	var sum: int = 0
	for r in dice_rolls:
		sum += r
	
	result.total = sum + flat_mod
	if result.total < 0: result.total = 0 # Damage tidak boleh minus
	
	return result

# ── STUBS UNTUK COMBAT (Tahap 3 Nanti) ───────────────────────

func roll_attack(attacker: Node, target: Node, dice_formula: String, attack_bonus: int) -> AttackRollResult:
	# Fungsi ini akan kita isi detailnya nanti saat integrasi dengan CombatComponent
	# Sementara kembalikan hasil kosong agar tidak error
	var res := AttackRollResult.new()
	return res

func get_roll_modifier(attacker: Node, target: Node) -> int:
	return 0
