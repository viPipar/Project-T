import os
import glob

BASE_DIR = r"c:\Users\rafid\Downloads\_Repos\Project-T\tiles_isometric_testing"
PIRATA_PATH = 'res://assets/ui_assets/PirataOne-Regular.ttf'
META_PATH = 'res://assets/ui_assets/Metamorphous-Regular.ttf'

def patch_tscn_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'type="SystemFont"' not in content and 'SystemFont_' not in content:
        return False

    print(f"Patching {filepath}...")

    # Insert ExtResources after gd_scene
    lines = content.split('\n')
    out_lines = []
    inserted = False
    
    for line in lines:
        out_lines.append(line)
        if line.startswith('[gd_scene') and not inserted:
            out_lines.append('')
            out_lines.append(f'[ext_resource type="FontFile" path="{PIRATA_PATH}" id="pirata_font"]')
            out_lines.append(f'[ext_resource type="FontFile" path="{META_PATH}" id="meta_font"]')
            inserted = True

    content = '\n'.join(out_lines)

    # Replacements
    content = content.replace('SubResource("SystemFont_title")', 'ExtResource("pirata_font")')
    content = content.replace('SubResource("SystemFont_bold")', 'ExtResource("pirata_font")')
    content = content.replace('SubResource("SystemFont_menu_btn")', 'ExtResource("meta_font")')
    content = content.replace('SubResource("SystemFont_label")', 'ExtResource("meta_font")')

    # Strip sub_resource blocks for SystemFont
    final_lines = []
    skip = False
    for line in content.split('\n'):
        if line.startswith('[sub_resource type="SystemFont"'):
            skip = True
            continue
        
        if skip:
            if line.startswith('['):
                skip = False
                final_lines.append(line)
            elif line.strip() == '':
                # Also skip empty lines that follow the block
                continue
        else:
            final_lines.append(line)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write('\n'.join(final_lines))
        
    return True

if __name__ == "__main__":
    patched_count = 0
    search_pattern = os.path.join(BASE_DIR, '**', '*.tscn')
    for filepath in glob.glob(search_pattern, recursive=True):
        # normalize slashes for matching
        filepath = os.path.normpath(filepath)
        if patch_tscn_file(filepath):
            patched_count += 1
            
    print(f"Successfully patched {patched_count} files.")
