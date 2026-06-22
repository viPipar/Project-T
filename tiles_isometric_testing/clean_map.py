import re

def fix_map():
    with open("world/maps/Map_2.tscn", "r") as f:
        lines = f.readlines()

    clean_lines = []
    # Remove ALL existing custom_data_0 = true lines to start fresh
    for l in lines:
        if re.match(r'^\d+:\d+/0/custom_data_0 = true\s*$', l):
            continue
        clean_lines.append(l)
        
    blocked_tiles = []
    # Row 4: logs and round rocks
    for x in range(4, 11):
        blocked_tiles.append((x, 4))
    
    # Row 5: all brown and gray rocks
    for x in range(0, 11):
        blocked_tiles.append((x, 5))
        
    # Row 6: all rocks in water
    for x in range(0, 11):
        blocked_tiles.append((x, 6))
        
    # Row 7: all small rocks in water
    for x in range(0, 11):
        blocked_tiles.append((x, 7))
    
    final_lines = []
    for l in clean_lines:
        final_lines.append(l)
        
        m = re.match(r'^(\d+):(\d+)/0 = 0\s*$', l)
        if m:
            x = int(m.group(1))
            y = int(m.group(2))
            if (x, y) in blocked_tiles:
                final_lines.append(f"{x}:{y}/0/custom_data_0 = true\n")
            
    with open("world/maps/Map_2.tscn", "w") as f:
        f.writelines(final_lines)

fix_map()
