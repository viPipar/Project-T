import base64
import struct

def parse_tilemap():
    with open("world/maps/Map_2.tscn", "r") as f:
        content = f.read()
        
    start_str = 'tile_map_data = PackedByteArray("'
    start_idx = content.find(start_str)
    start_idx += len(start_str)
    end_idx = content.find('")', start_idx)
    raw_data = base64.b64decode(content[start_idx:end_idx])
    
    # 2 bytes prefix
    prefix = struct.unpack("<h", raw_data[0:2])[0]
    print("Prefix:", prefix)
    
    for i in range(2, len(raw_data), 12):
        if i + 12 > len(raw_data): break
        chunk = raw_data[i:i+12]
        x, y, source, atlas_x, atlas_y, alt = struct.unpack("<hhhhhh", chunk)
        if x in [3, 4, 5, 6, 7] and y in [4, 5, 6, 7, 8]:
            print(f"Cell ({x}, {y}): source={source}, atlas=({atlas_x}, {atlas_y}), alt={alt}")

parse_tilemap()
