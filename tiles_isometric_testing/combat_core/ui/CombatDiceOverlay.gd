# combat_core/ui/CombatDiceOverlay.gd
# ─────────────────────────────────────────────────────────────────────────────
# CombatDiceOverlay
#
# CanvasLayer overlay yang tampil saat serangan dieksekusi.
# Mengorkestrasi animasi DiceVisual untuk D20 hit/miss check
# dan damage dice, lalu mengaplikasikan damage setelah selesai.
#
# Flow:
#   E/O tekan → CombatTestBridge resolve hasil → play_attack_sequence() →
#   [animasi D20] → HIT? → [animasi damage dice] → take_damage() → tutup
# ─────────────────────────────────────────────────────────────────────────────
class_name CombatDiceOverlay
extends CanvasLayer

# Diemit ketika seluruh sekuens animasi selesai
signal sequence_finished

# ── Node References ───────────────────────────────────────────────────────────
@onready var bg:             ColorRect  = $OverlayRoot/Background
@onready var dice_visual:    Node2D     = $OverlayRoot/DiceVisual
@onready var title_label:    Label      = $OverlayRoot/TitleLabel
@onready var subtitle_label: Label      = $OverlayRoot/SubtitleLabel
@onready var result_label:   Label      = $OverlayRoot/ResultLabel

# ── State ─────────────────────────────────────────────────────────────────────
var _is_playing: bool = false

# Durasi animasi (sesuai pilihan user)
const DURATION_D20:    float = 2.0
const DURATION_DAMAGE: float = 1.5
const PAUSE_AFTER_HIT: float = 0.6   # jeda antara D20 selesai dan damage roll mulai
const PAUSE_END:       float = 1.8   # jeda sebelum overlay ditutup


func _ready() -> void:
	layer = 10  # Pastikan di atas AttackCam dan semua UI
	visible = false


# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────

## Main entry point — dipanggil oleh CombatTestBridge.
## Fungsi ini BLOCKING (await-able) sampai seluruh animasi selesai.
##
## hit_result  : Dictionary dari CritResolver.resolve_with_crit()
##   Keys: "hit", "crit", "raw_roll", "roll", "threshold"
## dmg_rolls   : Array[int] hasil lemparan dadu damage (1 item normal, 2 item crit)
## dmg_total   : int total damage
## dmg_formula : String "1D8" dll
func play_attack_sequence(
	attacker: Node,
	target:   Node,
	hit_result:  Dictionary,
	dmg_rolls:   Array,
	dmg_total:   int,
	dmg_formula: String
) -> void:
	if _is_playing:
		return  # Hindari overlap

	_is_playing = true
	_show_overlay()

	var attacker_name: String = attacker.get("char_name") if attacker.get("char_name") else attacker.name
	var target_name:   String = target.get("enemy_name")  if target.get("enemy_name")  else target.name

	var raw_d20:   int  = hit_result.get("raw_roll",   1)
	var total_hit: int  = hit_result.get("roll",        1)
	var threshold: int  = hit_result.get("threshold",  10)
	var is_hit:    bool = hit_result.get("hit",        false)
	var is_crit:   bool = hit_result.get("crit",       false)

	# ── FASE 1: Roll D20 ──────────────────────────────────────────────────────
	title_label.text    = "%s → %s" % [attacker_name, target_name]
	subtitle_label.text = "🎲 Mengecek apakah serangan mengenai..."
	result_label.text   = ""

	dice_visual.start_roll(raw_d20, "d20", DURATION_D20)
	await dice_visual.roll_finished  # tunggu animasi D20 selesai

	# Tampilkan hasil D20
	result_label.text = "Roll D20: %d + modifier = %d  vs  Armor: %d" % [raw_d20, total_hit, threshold]

	# ── FASE 2: Branching MISS / HIT ─────────────────────────────────────────
	if not is_hit:
		# ── MISS ──────────────────────────────────────────────────────────────
		await get_tree().create_timer(0.4).timeout
		subtitle_label.text = "💨  MISS!"
		_flash_label(subtitle_label, Color(0.8, 0.8, 1.0))
		await get_tree().create_timer(PAUSE_END).timeout

	else:
		# ── HIT ───────────────────────────────────────────────────────────────
		await get_tree().create_timer(0.4).timeout
		if is_crit:
			subtitle_label.text = "💥 CRITICAL HIT!"
			_flash_label(subtitle_label, Color(1.0, 0.85, 0.0))
		else:
			subtitle_label.text = "✅ HIT!"
			_flash_label(subtitle_label, Color(0.3, 1.0, 0.5))

		await get_tree().create_timer(PAUSE_AFTER_HIT).timeout

		# ── FASE 3: Roll Damage Dice ──────────────────────────────────────────
		# Tampilkan setiap dadu damage secara berurutan
		var dice_type_str: String = _formula_to_dice_type(dmg_formula)
		var roll_summary:  String = ""

		for i in range(dmg_rolls.size()):
			subtitle_label.text = "🎲 Menghitung damage... (lemparan %d/%d)" % [i + 1, dmg_rolls.size()]
			result_label.text   = roll_summary

			dice_visual.start_roll(dmg_rolls[i], dice_type_str, DURATION_DAMAGE)
			await dice_visual.roll_finished  # tunggu tiap dadu selesai

			roll_summary += "Dadu %d: %d\n" % [i + 1, dmg_rolls[i]]
			result_label.text = roll_summary

			# Jeda 0.5s antar dadu (kecuali yang terakhir)
			if i < dmg_rolls.size() - 1:
				await get_tree().create_timer(0.5).timeout

		# Tampilkan total
		await get_tree().create_timer(0.3).timeout
		subtitle_label.text = "⚔️  Total Damage: %d!" % dmg_total
		_flash_label(subtitle_label, Color(1.0, 0.4, 0.2))
		result_label.text   = roll_summary + "\n→ TOTAL: %d" % dmg_total
		await get_tree().create_timer(PAUSE_END).timeout

	# ── SELESAI ───────────────────────────────────────────────────────────────
	_hide_overlay()
	_is_playing = false
	sequence_finished.emit()


## Cek apakah sedang menampilkan animasi
func is_playing() -> bool:
	return _is_playing


# ─────────────────────────────────────────────────────────────────────────────
# INTERNAL
# ─────────────────────────────────────────────────────────────────────────────

func _show_overlay() -> void:
	visible        = true
	title_label.text    = ""
	subtitle_label.text = ""
	result_label.text   = ""

	# Fade in background
	bg.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(bg, "modulate:a", 0.75, 0.25)


func _hide_overlay() -> void:
	var tween := create_tween()
	tween.tween_property(bg, "modulate:a", 0.0, 0.3)
	await tween.finished
	visible = false


func _flash_label(label: Label, color: Color) -> void:
	label.modulate = color
	var tween := create_tween()
	tween.tween_property(label, "modulate", Color.WHITE, 0.6)


## Ekstrak tipe dadu dari formula string (misal "1D8" → "d8")
func _formula_to_dice_type(formula: String) -> String:
	formula = formula.to_lower().replace(" ", "")
	var parts := formula.split("d")
	if parts.size() == 2:
		return "d" + parts[1].split("+")[0].split("-")[0]
	return "custom"
