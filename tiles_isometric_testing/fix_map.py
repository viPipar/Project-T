import re

def fix_map():
    with open("world/maps/Map_2.tscn", "r") as f:
        lines = f.readlines()

    clean_lines = []
    # Remove existing custom_data_0 for rows 5-10
    for l in lines:
        if re.match(r'^\d+:([56789]|10)/0/custom_data_0 = true\s*$', l):
            continue
        clean_lines.append(l)
        
    final_lines = []
    for l in clean_lines:
        final_lines.append(l)
        m = re.match(r'^(\d+):([56789]|10)/0 = 0\s*$', l)
        if m:
            x = m.group(1)
            y = m.group(2)
            final_lines.append(f"{x}:{y}/0/custom_data_0 = true\n")
            
    with open("world/maps/Map_2.tscn", "w") as f:
        f.writelines(final_lines)

fix_map()
