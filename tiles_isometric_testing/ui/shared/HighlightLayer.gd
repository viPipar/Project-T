extends Node2D

# =============================================================================
#  HighlightLayer.gd
#
#  Script ini dipasang di HighlightLayer.tscn.
#  Tugasnya:
#    1. Mendaftarkan dirinya ke HighlightManager saat _ready()
#    2. Menjadi wadah (parent) bagi semua AnimatedSprite2D highlight
#
#  Di dalam HighlightLayer.tscn, buat node anak AnimatedSprite2D
#  satu per tipe highlight, dengan nama persis seperti di HIGHLIGHT_CONFIG:
#
#    HighlightLayer (Node2D) ← script ini
#    ├── MoveHighlight   (AnimatedSprite2D) ← SpriteFrames berisi animasi "move"
#    ├── AttackHighlight (AnimatedSprite2D) ← SpriteFrames berisi animasi "attack"
#    ├── SelectHighlight (AnimatedSprite2D) ← SpriteFrames berisi animasi "select"
#    ├── SkillHighlight  (AnimatedSprite2D) ← SpriteFrames berisi animasi "skill"
#    ├── HoverHighlight  (AnimatedSprite2D) ← SpriteFrames berisi animasi "hover"
#    └── DangerHighlight (AnimatedSprite2D) ← SpriteFrames berisi animasi "danger"
#
#  Setiap node di atas adalah "template". HighlightManager.gd akan
#  men-duplicate()-nya setiap kali butuh instance baru.
#  Set visible = false pada semua template di editor.
# =============================================================================

func _ready() -> void:
	# Daftarkan layer ini ke HighlightManager autoload
	if Engine.has_singleton("HighlightManager"):
		HighlightManager.register_layer(self)
	else:
		# Kalau HighlightManager belum jadi autoload, coba lewat get_node
		var hm = get_node_or_null("/root/HighlightManager")
		if hm:
			hm.register_layer(self)
		else:
			push_error("HighlightLayer: HighlightManager autoload tidak ditemukan!")
