extends Node

# Tanggung jawab:
#   Menangani inisialisasi arena combat, memuat resource, dan menempatkan player
#   saat terjadi transisi dari MapScreen (Roguelike meta-loop) ke Combat state.

signal combat_ready()

func _ready() -> void:
	if EventBus != null:
		EventBus.start_combat.connect(_on_start_combat)

func _on_start_combat(node_type: int) -> void:
	print("[CombatManager] Mempersiapkan arena combat untuk node type: ", node_type)
	
	# TODO: Load combat scene/arena, spawn enemies based on node_type (ELITE, BOSS, BATTLE)
	# Transisi kamera dari Map ke Combat Arena
	
	# Contoh memanggil TurnManager (hanya jika memang diserahkan ke CombatManager)
	if TurnManager != null and TurnManager.has_method("start_battle"):
		# TurnManager.start_battle() bisa dipanggil setelah loading scene selesai
		pass
	
	combat_ready.emit()
