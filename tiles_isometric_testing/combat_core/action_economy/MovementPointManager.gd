# combat_core/action_economy/MovementPointManager.gd
# Phase 2 — Action Economy
# Mengelola Movement Point (tiles) per entity
#
# Formula dari GDD:
#   Movement = 6 + floor(MOV / 5)
class_name MovementPointManager
extends Node

signal movement_changed(current: int, max_tiles: int)

var max_tiles    : int = 6
var current_tiles: int = 6


# ── SETUP ─────────────────────────────────────────────────────────────────────

func setup(mov_stat: int) -> void:
	max_tiles     = 6 + floori(mov_stat / 5.0)
	current_tiles = max_tiles
	movement_changed.emit(current_tiles, max_tiles)

func setup_from_stats(stats: StatsComponent) -> void:
	setup(stats.get_stat("mov"))


# ── ITEM BONUS ────────────────────────────────────────────────────────────────

func add_movement_bonus(amount: int) -> void:
	max_tiles     += amount
	current_tiles = min(current_tiles + amount, max_tiles)
	movement_changed.emit(current_tiles, max_tiles)


# ── SPEND ─────────────────────────────────────────────────────────────────────

## Pakai movement tiles — return true jika berhasil
func spend_movement(tiles: int) -> bool:
	if current_tiles >= tiles:
		current_tiles -= tiles
		movement_changed.emit(current_tiles, max_tiles)
		return true
	return false

func can_move(tiles: int) -> bool:
	return current_tiles >= tiles

func has_movement() -> bool:
	return current_tiles > 0

func tiles_remaining() -> int:
	return current_tiles


# ── RESET (awal giliran) ─────────────────────────────────────────────────────

func reset() -> void:
	current_tiles = max_tiles
	movement_changed.emit(current_tiles, max_tiles)
