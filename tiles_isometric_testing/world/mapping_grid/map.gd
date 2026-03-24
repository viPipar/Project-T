extends Node
class_name MapData

# Simpan semua koordinat tembok dalam Dictionary
# Key: ID Map (1, 2, 3, dst)
# Value: Array koordinat tembok
const WALLS = {
	1: [
		Vector2i(2, 6), Vector2i(4, 5), Vector2i(4, 2),
		Vector2i(3, 2), Vector2i(6, 1), Vector2i(9, 6), 
		Vector2i(9, 10), Vector2i(14, 10), Vector2i(12, 13),
		Vector2i(18, 14), Vector2i(7, 7)
	],
	2: [
		Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3),
		Vector2i(8, 8), Vector2i(9, 8)
	],
	3: [
		Vector2i(10, 5), Vector2i(10, 6)
	],
	# Lanjutkan sampai map 6...
}

# Fungsi untuk mengambil data tembok berdasarkan ID map
static func get_walls(map_id: int) -> Array[Vector2i]:
	var data = WALLS.get(map_id, [])
	return Array(data, TYPE_VECTOR2I, &"", null)
