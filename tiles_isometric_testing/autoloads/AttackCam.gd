extends CanvasLayer

signal cam_finished

@export var sfx_p1_stream: AudioStream
@export var sfx_p2_stream: AudioStream

@onready var p1:      Node2D            = $AttackCamP1
@onready var p2:      Node2D            = $AttackCamP2
@onready var anim_p1: AnimatedSprite2D  = $AttackCamP1/AnimatedSprite2D
@onready var anim_p2: AnimatedSprite2D  = $AttackCamP2/AnimatedSprite2D
@onready var sfx_p1:  AudioStreamPlayer = $SFX_P1
@onready var sfx_p2:  AudioStreamPlayer = $SFX_P2

const ANIM := "default"

var _pending: int = 0

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	visible = false
	anim_p1.animation_finished.connect(_on_done)
	anim_p2.animation_finished.connect(_on_done)
	sfx_p1.finished.connect(_on_done)
	sfx_p2.finished.connect(_on_done)

	# assign sfx dari export

# ─────────────────────────────────────────────────────────────────────────────
#  Public API — tinggal bilang siapa yang tampil
# ─────────────────────────────────────────────────────────────────────────────

func play(show_p1: bool, show_p2: bool) -> void:
	_pending = 0
	visible  = true

	if show_p1:
		p1.show()
		anim_p1.play(ANIM)
		_pending += 1
		if sfx_p1.stream != null:
			sfx_p1.play()
			_pending += 1

	if show_p2:
		p2.show()
		anim_p2.play(ANIM)
		_pending += 1
		if sfx_p2.stream != null:
			sfx_p2.play()
			_pending += 1

	if _pending == 0:
		push_warning("AttackCam.play() dipanggil tapi tidak ada yang aktif!")
		_finish()

func hide_cam() -> void:
	anim_p1.stop()
	anim_p2.stop()
	sfx_p1.stop()
	sfx_p2.stop()
	p1.hide()
	p2.hide()
	_pending = 0
	_finish()

# ─────────────────────────────────────────────────────────────────────────────

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
