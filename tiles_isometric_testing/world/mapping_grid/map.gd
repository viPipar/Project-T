extends Node
class_name MapData

# Simpan semua koordinat tembok dalam Dictionary
# Key: ID Map (1, 2, 3, dst)
# Value: Array koordinat tembok
const WALLS = {
	1: [
		# Area non-playable / batas map.
		Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
		Vector2i(0, 4), Vector2i(0, 5), Vector2i(0, 6), Vector2i(0, 7),
		Vector2i(0, 8), Vector2i(0, 9), Vector2i(0, 10), Vector2i(0, 11),
		Vector2i(0, 12), Vector2i(0, 13), Vector2i(0, 14), Vector2i(0, 15),

		Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3),
		Vector2i(1, 4), Vector2i(1, 5), Vector2i(1, 6), Vector2i(1, 7),
		Vector2i(1, 8), Vector2i(1, 9), Vector2i(1, 10), Vector2i(1, 11),
		Vector2i(1, 12), Vector2i(1, 13), Vector2i(1, 14), Vector2i(1, 15),

		Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3),
		Vector2i(2, 8), Vector2i(2, 9), Vector2i(2, 10), Vector2i(2, 11),
		Vector2i(2, 12), Vector2i(2, 13), Vector2i(2, 14), Vector2i(2, 15),

		Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2),
		Vector2i(3, 10), Vector2i(3, 11), Vector2i(3, 12),
		Vector2i(3, 13), Vector2i(3, 14), Vector2i(3, 15),

		Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2),
		Vector2i(4, 12), Vector2i(4, 13), Vector2i(4, 14), Vector2i(4, 15),

		Vector2i(5, 0), Vector2i(5, 1),
		Vector2i(5, 13), Vector2i(5, 14), Vector2i(5, 15),

		Vector2i(6, 0), Vector2i(6, 1),
		Vector2i(6, 14), Vector2i(6, 15),

		Vector2i(7, 0), Vector2i(7, 1), Vector2i(7, 2),
		Vector2i(7, 13), Vector2i(7, 14), Vector2i(7, 15),

		Vector2i(8, 0), Vector2i(8, 1), Vector2i(8, 2),
		Vector2i(8, 14), Vector2i(8, 15),

		Vector2i(9, 0), Vector2i(9, 1),
		Vector2i(9, 14), Vector2i(9, 15),

		Vector2i(10, 0), Vector2i(10, 1), Vector2i(10, 2),
		Vector2i(10, 14), Vector2i(10, 15),

		Vector2i(11, 0), Vector2i(11, 1), Vector2i(11, 2),
		Vector2i(11, 14), Vector2i(11, 15),

		Vector2i(12, 0), Vector2i(12, 1), Vector2i(12, 2), Vector2i(12, 3),
		Vector2i(12, 4), Vector2i(12, 13), Vector2i(12, 14), Vector2i(12, 15),

		Vector2i(13, 0), Vector2i(13, 1), Vector2i(13, 2), Vector2i(13, 3),
		Vector2i(13, 4), Vector2i(13, 5), Vector2i(13, 6),
		Vector2i(13, 12), Vector2i(13, 13), Vector2i(13, 14), Vector2i(13, 15),

		Vector2i(14, 0), Vector2i(14, 1), Vector2i(14, 2), Vector2i(14, 3),
		Vector2i(14, 4), Vector2i(14, 5), Vector2i(14, 6), Vector2i(14, 7),
		Vector2i(14, 10), Vector2i(14, 11), Vector2i(14, 12),
		Vector2i(14, 13), Vector2i(14, 14), Vector2i(14, 15),

		Vector2i(15, 0), Vector2i(15, 1), Vector2i(15, 2), Vector2i(15, 3),
		Vector2i(15, 4), Vector2i(15, 5), Vector2i(15, 6), Vector2i(15, 7),
		Vector2i(15, 8), Vector2i(15, 9), Vector2i(15, 10), Vector2i(15, 11),
		Vector2i(15, 12), Vector2i(15, 13), Vector2i(15, 14), Vector2i(15, 15),

		# Batu di dalam area playable.
		Vector2i(9, 10), Vector2i(9, 6), Vector2i(4, 5), Vector2i(2, 6)
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
