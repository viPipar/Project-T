extends CanvasLayer
## jangan hapus bagian tutorial makai ini (haram hukumnya, perbaiki jika perlu)
#Paling simple — semua default 
#       AttackCam.play(true, false)
#Animasi custom P1, SFX default
#       AttackCam.play(true, false, "slash")
# Animasi custom P2, SFX custom
#       AttackCam.play(false, true, "", "magic", "", "SFX_Magic")
# Keduanya custom semua
#AttackCam.play(true, true, "slash", "magic", "SFX_Sword", "SFX_Magic")

### Struktur node yang diharapkan

#AttackCam (CanvasLayer)
#  ├─ AttackCamP1
#  │    └─ AnimatedSprite2D
#  ├─ AttackCamP2
#  │    └─ AnimatedSprite2D
#  ├─ SFX_P1          ← default P1
#  ├─ SFX_P2          ← default P2
#  ├─ SFX_Sword       ← custom, tinggal sebut namanya
#  └─ SFX_Magic       ← custom, tinggal sebut namanya

signal cam_finished

@onready var p1:      Node2D           = $AttackCamP1
@onready var p2:      Node2D           = $AttackCamP2
@onready var anim_p1: AnimatedSprite2D = $AttackCamP1/AnimatedSprite2D
@onready var anim_p2: AnimatedSprite2D = $AttackCamP2/AnimatedSprite2D

const DEFAULT_ANIM  := "default"
const DEFAULT_SFX_P1 := "SFX_P1"
const DEFAULT_SFX_P2 := "SFX_P2"

var _pending: int = 0
var _active_sfx: Array[AudioStreamPlayer] = []

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	visible = false
	anim_p1.animation_finished.connect(_on_done)
	anim_p2.animation_finished.connect(_on_done)

# ─────────────────────────────────────────────────────────────────────────────
#  Public API
#  show_p1      : tampilkan P1?
#  show_p2      : tampilkan P2?
#  anim_p1_name : nama animasi P1, fallback ke "default" kalau tidak ada
#  anim_p2_name : nama animasi P2, fallback ke "default" kalau tidak ada
#  sfx_p1_name  : nama node SFX untuk P1, default "SFX_P1"
#  sfx_p2_name  : nama node SFX untuk P2, default "SFX_P2"
# ─────────────────────────────────────────────────────────────────────────────

func play(
	show_p1:      bool,
	show_p2:      bool,
	anim_p1_name: String = DEFAULT_ANIM,
	anim_p2_name: String = DEFAULT_ANIM,
	sfx_p1_name:  String = DEFAULT_SFX_P1,
	sfx_p2_name:  String = DEFAULT_SFX_P2
) -> void:
	_pending    = 0
	_active_sfx = []
	visible     = true

	if show_p1:
		p1.show()
		anim_p1.play(_resolve_anim(anim_p1, anim_p1_name))
		_pending += 1
		_try_play_sfx(sfx_p1_name)

	if show_p2:
		p2.show()
		anim_p2.play(_resolve_anim(anim_p2, anim_p2_name))
		_pending += 1
		_try_play_sfx(sfx_p2_name)

	if _pending == 0:
		push_warning("AttackCam.play() dipanggil tapi tidak ada yang aktif!")
		_finish()

func hide_cam() -> void:
	anim_p1.stop()
	anim_p2.stop()
	for sfx in _active_sfx:
		sfx.stop()
	p1.hide()
	p2.hide()
	_pending = 0
	_finish()

# ─────────────────────────────────────────────────────────────────────────────
#  Internal
# ─────────────────────────────────────────────────────────────────────────────

# Cek animasi ada atau tidak, fallback ke default
func _resolve_anim(sprite: AnimatedSprite2D, anim_name: String) -> String:
	if sprite.sprite_frames.has_animation(anim_name):
		return anim_name
	push_warning("AttackCam: animasi '%s' tidak ada, pakai '%s'" % [anim_name, DEFAULT_ANIM])
	return DEFAULT_ANIM

# Cari node SFX by name, connect signal, lalu play
func _try_play_sfx(sfx_node_name: String) -> void:
	var sfx := get_node_or_null(sfx_node_name) as AudioStreamPlayer
	if sfx == null:
		push_warning("AttackCam: node SFX '%s' tidak ditemukan" % sfx_node_name)
		return
	if sfx.stream == null:
		push_warning("AttackCam: node SFX '%s' tidak ada stream" % sfx_node_name)
		return

	# Connect sekali saja (kalau sudah connect skip)
	if not sfx.finished.is_connected(_on_done):
		sfx.finished.connect(_on_done)

	_active_sfx.append(sfx)
	sfx.play()
	_pending += 1

func _on_done() -> void:
	_pending -= 1
	if _pending <= 0:
		_finish()

func _finish() -> void:
	p1.hide()
	p2.hide()
	visible  = false
	_pending = 0
	cam_finished.emit()
