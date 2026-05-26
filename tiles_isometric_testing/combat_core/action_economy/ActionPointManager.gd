# combat_core/action_economy/ActionPointManager.gd
# Phase 2 — Action Economy
# Mengelola Action Point (AP) dan Bonus Action Point (BAP) per entity
#
# Formula dari GDD:
#   AP base  = 1 + floor(DEX / 10)
#   BAP base = 1 + floor(INT / 10)
class_name ActionPointManager
extends Node

signal ap_changed(current_ap: int, max_ap: int)
signal bap_changed(current_bap: int, max_bap: int)

var max_ap     : int = 1
var current_ap : int = 1
var max_bap    : int = 1
var current_bap: int = 1


# ── SETUP ─────────────────────────────────────────────────────────────────────

## Inisialisasi dari stat DEX dan INT entity
func setup(dex: int, int_stat: int) -> void:
	max_ap  = 1 + floori(dex / 10.0)
	max_bap = 1 + floori(int_stat / 10.0)
	reset()


## Setup dari StatsComponent langsung (shortcut untuk integrasi)
func setup_from_stats(stats: StatsComponent) -> void:
	setup(stats.get_stat("dex"), stats.get_stat("int"))


# ── ITEM BONUS ────────────────────────────────────────────────────────────────

## Tambah bonus AP dari item (permanent until removed)
func add_ap_bonus(amount: int) -> void:
	max_ap     += amount
	current_ap = min(current_ap + amount, max_ap)
	ap_changed.emit(current_ap, max_ap)

func add_bap_bonus(amount: int) -> void:
	max_bap     += amount
	current_bap = min(current_bap + amount, max_bap)
	bap_changed.emit(current_bap, max_bap)


# ── SPEND ─────────────────────────────────────────────────────────────────────

## Coba pakai AP — return true jika berhasil
func spend_ap(amount: int = 1) -> bool:
	if current_ap >= amount:
		current_ap -= amount
		ap_changed.emit(current_ap, max_ap)
		return true
	return false

func spend_bap(amount: int = 1) -> bool:
	if current_bap >= amount:
		current_bap -= amount
		bap_changed.emit(current_bap, max_bap)
		return true
	return false


# ── QUERY (untuk HUD preview skill) ──────────────────────────────────────────

func can_spend_ap(amount: int = 1)  -> bool: return current_ap  >= amount
func can_spend_bap(amount: int = 1) -> bool: return current_bap >= amount

func has_any_ap()  -> bool: return current_ap  > 0
func has_any_bap() -> bool: return current_bap > 0


# ── RESET (awal giliran) ─────────────────────────────────────────────────────

func reset() -> void:
	current_ap  = max_ap
	current_bap = max_bap
	ap_changed.emit(current_ap, max_ap)
	bap_changed.emit(current_bap, max_bap)
