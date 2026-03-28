extends Node

const TILE_W: int = 256
const TILE_H: int = 128

# Grid (x,y) -> pixel di layar
func world_to_iso(grid_pos: Vector2i) -> Vector2:
	var px: float = (grid_pos.x - grid_pos.y) * (TILE_W / 2.0)
	var py: float = (grid_pos.x + grid_pos.y) * (TILE_H / 2.0)
	return Vector2(px, py)

# Pixel -> grid (x,y) — dipakai buat klik mouse nanti
func iso_to_grid(pixel: Vector2) -> Vector2i:
	var gx: float = (pixel.x / (TILE_W / 2.0) + pixel.y / (TILE_H / 2.0)) / 2.0
	var gy: float = (pixel.y / (TILE_H / 2.0) - pixel.x / (TILE_W / 2.0)) / 2.0
	return Vector2i(int(floor(gx)), int(floor(gy)))

# z_index berdasarkan posisi grid
func get_depth(grid_pos: Vector2i) -> int:
	return grid_pos.x + grid_pos.y
