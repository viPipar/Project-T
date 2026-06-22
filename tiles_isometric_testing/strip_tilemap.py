import re

with open("main/Main.tscn", "r", encoding="utf-8") as f:
    content = f.read()

start_idx = content.find('[node name="TileMapLayer" type="TileMapLayer" parent="World"]')
if start_idx != -1:
    end_idx = content.find('[sub_resource', start_idx)
    if end_idx == -1:
        end_idx = content.find('[node', start_idx + 1)
        if end_idx == -1:
            end_idx = len(content)
            
    content = content[:start_idx] + content[end_idx:]
    
    with open("main/Main.tscn", "w", encoding="utf-8") as f:
        f.write(content)
    print("TileMapLayer removed from Main.tscn")
else:
    print("TileMapLayer not found in Main.tscn")
