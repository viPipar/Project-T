extends Node2D
class_name MapLevel

## Komponen mandiri untuk Map.
## Jika di-instance ke dalam scene yang memiliki GridManager (Autoload),
## MapLevel akan secara otomatis memindai TileMapLayer di dalamnya
## dan mendaftarkan tembok/jalur ke GridManager.

@export var map_id: int = 1
@onready var tilemap: TileMapLayer = $TileMapLayer

func _ready() -> void:
	if tilemap == null:
		push_warning("[MapLevel] TileMapLayer tidak ditemukan di dalam map ini!")
		return
		
	if GridManager == null:
		return
		
	# Pastikan state grid bersih sebelum membaca map baru
	if GridManager.has_method("clear_state"):
		GridManager.clear_state()
		
	GridManager.current_map_id = map_id
	
	var walls: Array[Vector2i] = []
	var used_cells = tilemap.get_used_cells()
	
	# Deteksi dimensi map
	var max_x = 0
	var max_y = 0
	
	for pos in used_cells:
		if pos.x > max_x: max_x = pos.x
		if pos.y > max_y: max_y = pos.y
		
		# Baca Custom Data dari TileSet (Layer 0: "Blocked")
		var tile_data = tilemap.get_cell_tile_data(pos)
		if tile_data and tile_data.get_custom_data("Blocked") == true:
			walls.append(pos)
			
	# Buat Grid berdasarkan ukuran peta + 1 (karena index 0)
	GridManager.setup_grid(max_x + 1, max_y + 1)
	
	# Daftarkan semua tembok yang ditemukan
	GridManager.setup_walls(walls)
	GridManager.map_changed.emit(map_id)
	
	print("[MapLevel] Berhasil memuat Map %d berukuran %dx%d dengan %d tembok." % [map_id, max_x + 1, max_y + 1, walls.size()])
