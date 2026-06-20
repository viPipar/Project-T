# ui/shared/FloatingDamageNumber.gd
# ── Floating combat text juicy ala Genshin Impact / Honkai Star Rail ─────────
# Spawn sebagai Node2D di world tree → otomatis terlihat di kedua viewport (shared World2D)
#
# Cara pakai (FloatingTextManager):
#   var inst = scene.instantiate()
#   world_node.add_child(inst)
#   inst.global_position = target.global_position + Vector2(0, -50)
#   inst.display(amount, "damage")  # atau "crit" / "heal" / "miss"
class_name FloatingDamageNumber
extends Node2D

# ── Config per tipe ───────────────────────────────────────────────────────────
const CONFIGS := {
	"damage": {
		"color":        Color(1.0,  1.0,  1.0,  1.0),   # putih bersih
		"outline":      Color(0.08, 0.04, 0.08, 1.0),   # hitam keunguan
		"font_size":    44,
		"scale_peak":   Vector2(1.25, 1.25),
		"float_dist":   80.0,
		"italic":       false,
	},
	"crit": {
		"color":        Color(1.0,  0.42, 0.12, 1.0),   # oranye-api
		"outline":      Color(0.6,  0.1,  0.0,  1.0),   # merah gelap
		"font_size":    60,
		"scale_peak":   Vector2(1.4, 1.4),
		"float_dist":   110.0,
		"italic":       false,
	},
	"heal": {
		"color":        Color(0.3,  1.0,  0.6,  1.0),   # hijau mint
		"outline":      Color(0.0,  0.3,  0.1,  1.0),   # hijau tua
		"font_size":    40,
		"scale_peak":   Vector2(1.2, 1.2),
		"float_dist":   70.0,
		"italic":       false,
	},
	"miss": {
		"color":        Color(0.65, 0.65, 0.65, 1.0),   # abu-abu
		"outline":      Color(0.0,  0.0,  0.0,  1.0),
		"font_size":    28,
		"scale_peak":   Vector2(1.1, 1.1),
		"float_dist":   50.0,
		"italic":       true,
	},
}

# ── State ─────────────────────────────────────────────────────────────────────
var _label       : Label
var _shadow_lbl  : Label   # shadow layer untuk crit glow
var _type        : String  = "damage"


func _ready() -> void:
	z_index = 100   # tampil di atas sprite entity


# ── PUBLIC API ────────────────────────────────────────────────────────────────

func display(amount: int, type: String) -> void:
	_type = type if CONFIGS.has(type) else "damage"
	var cfg : Dictionary = CONFIGS[_type]

	# ── Buat shadow label (hanya untuk crit) ──────────────────────────────────
	if _type == "crit":
		_shadow_lbl = _make_label(
			str(amount),
			cfg["font_size"],
			Color(1.0, 0.9, 0.0, 0.55),   # glow kuning
			Color(0.0, 0.0, 0.0, 0.0),    # no outline di shadow
			0,
			false
		)
		# Shadow sedikit offset ke kanan-bawah dari main label
		_shadow_lbl.position = Vector2(-98, -36)
		add_child(_shadow_lbl)

	# ── Buat main label ────────────────────────────────────────────────────────
	var display_text := str(amount) if type != "miss" else "MISS"
	_label = _make_label(
		display_text,
		cfg["font_size"],
		cfg["color"],
		cfg["outline"],
		6,
		cfg["italic"]
	)
	add_child(_label)

	# ── Sedikit random horizontal offset agar tidak overlap saat multi-hit ────
	var rand_x := randf_range(-18.0, 18.0)
	position.x += rand_x

	# ── Jalankan animasi ──────────────────────────────────────────────────────
	_animate(cfg)


# ── ANIMATION ─────────────────────────────────────────────────────────────────

func _animate(cfg: Dictionary) -> void:
	var peak   : Vector2 = cfg["scale_peak"]
	var dist   : float   = cfg["float_dist"]

	# Start: tidak terlihat, scale kecil
	scale        = Vector2(0.1, 0.1)
	modulate.a   = 1.0

	var total_time := 0.9   # total durasi hidup teks

	# ── Step 1: Pop scale (TRANS_BACK = bounce elastis) ───────────────────────
	var tw := create_tween()
	tw.tween_property(self, "scale", peak, 0.14)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# ── Step 2: Float naik (bersamaan dengan fade out di akhir) ───────────────
	var tw2 := create_tween()
	tw2.tween_property(self, "position:y", position.y - dist, total_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# ── Step 3: Fade out di 40% terakhir ─────────────────────────────────────
	var tw3 := create_tween()
	tw3.tween_interval(total_time * 0.6)
	tw3.tween_property(self, "modulate:a", 0.0, total_time * 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Tambahan: Crit juga punya efek "ring expand" kecil (label scale tambahan)
	if _type == "crit":
		var tw_crit := create_tween()
		tw_crit.tween_property(self, "scale", Vector2(1.1, 1.1), 0.08)
		tw_crit.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

	# Tunggu selesai lalu bersihkan
	await tw3.finished
	queue_free()


# ── HELPERS ───────────────────────────────────────────────────────────────────

func _make_label(
	text       : String,
	font_size  : int,
	color      : Color,
	outline    : Color,
	outline_sz : int,
	_italic    : bool
) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if outline_sz > 0:
		l.add_theme_color_override("font_outline_color", outline)
		l.add_theme_constant_override("outline_size", outline_sz)
	# Posisi manual di Node2D: anchor ke tengah dengan offset
	# Label di-set size cukup lebar agar teks tidak terpotong
	l.size = Vector2(200, 80)
	l.position = Vector2(-100, -40)   # offset agar label center di origin Node2D
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

