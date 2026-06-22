import base64
import struct

def parse_tilemap():
    with open("world/maps/Map_2.tscn", "r") as f:
        content = f.read()
        
    start_str = 'tile_map_data = PackedByteArray("'
    start_idx = content.find(start_str)
    if start_idx == -1:
        print("No tile_map_data found!")
        return
    start_idx += len(start_str)
    end_idx = content.find('")', start_idx)
    raw_data = base64.b64decode(content[start_idx:end_idx])
    
    print("Total bytes:", len(raw_data))
    for i in range(0, len(raw_data), 12):
        if i + 12 > len(raw_data): break
        chunk = raw_data[i:i+12]
        # Godot 4.3 TileMapLayer:
        # x (16-bit), y (16-bit), source_id (16-bit), atlas_x (16-bit), atlas_y (16-bit), alternative_tile (16-bit)
        x, y, source, atlas_x, atlas_y, alt = struct.unpack("<hhhhhh", chunk)
        if x in [3, 4, 5, 6, 7] and y in [4, 5, 6, 7, 8]:
            print(f"Cell ({x}, {y}): source={source}, atlas=({atlas_x}, {atlas_y})")

parse_tilemap()
