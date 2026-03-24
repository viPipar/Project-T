extends Node
# ─────────────────────────────────────────────────────────────────────────────
#  ProjectileLine  (Autoload)
#
#  Traces a grid-space line from `origin` toward `target` using Bresenham's
#  algorithm, testing every tile the line passes through.
#
#  Returns a Dictionary:
#    {
#      "result":   "hit_entity" | "hit_wall" | "miss",
#      "tile":     Vector2i,   # tile where the line stopped (or target if miss)
#      "tiles":    Array[Vector2i]  # every tile visited, in order
#    }
#
#  Usage:
#    var shot = ProjectileLine.cast(shooter.grid_pos, target_tile)
#    if shot.result == "hit_entity":   ...
#    elif shot.result == "hit_wall":   ...
#    else:                             ...  # miss / nothing in the way
# ─────────────────────────────────────────────────────────────────────────────


## Cast a line from `origin` to `target` and report what it hits first.
## `origin` is excluded from collision checks (the shooter never blocks itself).
func cast(origin: Vector2i, target: Vector2i) -> Dictionary:
	var tiles: Array[Vector2i] = _bresenham(origin, target)

	for i in range(tiles.size()):
		var tile := tiles[i]

		if tile == origin:
			continue

		# 1. CEK TEMBOK ASLI (Hanya cek terrain flag)
		# Gunakan is_terrain_walkable agar entity tidak dianggap tembok
		if not GridManager.is_terrain_walkable(tile):
			return {
				"result": "hit_wall",
				"tile":   tile,
				"tiles":  tiles.slice(0, i + 1),
			}

		# 2. CEK ENTITY (Musuh/Pemain)
		if GridManager.has_entity_at(tile):
			return {
				"result": "hit_entity",
				"tile":   tile,
				"tiles":  tiles.slice(0, i + 1),
			}

	return {
		"result": "miss",
		"tile":   target,
		"tiles":  tiles,
	}


## Same as cast() but stops after `max_range` tiles so you can model weapon range.
func cast_ranged(origin: Vector2i, target: Vector2i, max_range: int) -> Dictionary:
	var full_tiles: Array[Vector2i] = _bresenham(origin, target)

	# Clamp the path to max_range steps past the origin
	var clamped: Array[Vector2i] = []
	var steps := 0
	for tile in full_tiles:
		clamped.append(tile)
		if tile != origin:
			steps += 1
			if steps >= max_range:
				break

	# Re-use cast logic on the clamped endpoint
	var clamped_target := clamped[clamped.size() - 1]
	var result := cast(origin, clamped_target)

	# If it was a miss but we clamped, mark as miss at the range limit
	if result.result == "miss" and clamped_target != target:
		result["out_of_range"] = true

	return result


# ── Bresenham ─────────────────────────────────────────────────────────────────

## Returns every grid tile the line from p0 to p1 passes through (inclusive).
func _bresenham(p0: Vector2i, p1: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []

	var x  := p0.x
	var y  := p0.y
	var dx := absi(p1.x - p0.x)
	var dy := absi(p1.y - p0.y)
	var sx := 1 if p1.x > p0.x else -1
	var sy := 1 if p1.y > p0.y else -1
	var err := dx - dy

	while true:
		tiles.append(Vector2i(x, y))

		if x == p1.x and y == p1.y:
			break

		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x   += sx
		if e2 < dx:
			err += dx
			y   += sy

	return tiles
