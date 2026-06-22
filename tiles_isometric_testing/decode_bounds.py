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
    
    print("Total tiles:", len(raw_data) // 12)
    coords = []
    for i in range(0, len(raw_data), 12):
        if i + 12 > len(raw_data): break
        chunk = raw_data[i:i+12]
        x, y, source, atlas_x, atlas_y, alt = struct.unpack("<hhhhhh", chunk)
        coords.append((x, y))
        
    min_x = min([c[0] for c in coords])
    max_x = max([c[0] for c in coords])
    min_y = min([c[1] for c in coords])
    max_y = max([c[1] for c in coords])
    
    print(f"X range: {min_x} to {max_x}")
    print(f"Y range: {min_y} to {max_y}")

parse_tilemap()
