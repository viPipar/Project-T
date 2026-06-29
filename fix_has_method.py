import os
import re

directory = "tiles_isometric_testing"

# Regex to match: if <var>.has_method
# We need to capture the variable name.
# Also handle if <var> != null and <var>.has_method

pattern1 = re.compile(r'if\s+([a-zA-Z0-9_\.\(\)\[\]]+)\s*!=\s*null\s+and\s+\1\.has_method\(')
pattern2 = re.compile(r'if\s+([a-zA-Z0-9_\.\(\)\[\]]+)\.has_method\(')
pattern3 = re.compile(r'elif\s+([a-zA-Z0-9_\.\(\)\[\]]+)\.has_method\(')

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    
    # First pass: replace 'if var != null and var.has_method' with 'if is_instance_valid(var) and var.has_method'
    # Wait, some vars might be single letters or properties like 'entity'
    
    lines = content.split('\n')
    new_lines = []
    changed = False
    
    for line in lines:
        if 'has_method' not in line:
            new_lines.append(line)
            continue
            
        # Avoid replacing if it already has is_instance_valid
        if 'is_instance_valid' in line:
            new_lines.append(line)
            continue
            
        # Also avoid replacing if it's checking EventBus or StatSystem or TurnManager (singletons)
        # We can just blindly replace because is_instance_valid works on singletons too!
        # Wait, if we replace `if cond.has_method` with `if is_instance_valid(cond) and cond.has_method` it's perfect.
        
        # Match elif
        m = pattern3.search(line)
        if m:
            var_name = m.group(1)
            line = line[:m.start()] + f"elif is_instance_valid({var_name}) and {var_name}.has_method(" + line[m.end():]
            changed = True
            new_lines.append(line)
            continue

        # Match pattern 1
        m = pattern1.search(line)
        if m:
            var_name = m.group(1)
            line = line[:m.start()] + f"if is_instance_valid({var_name}) and {var_name}.has_method(" + line[m.end():]
            changed = True
            new_lines.append(line)
            continue
            
        # Match pattern 2
        m = pattern2.search(line)
        if m:
            var_name = m.group(1)
            line = line[:m.start()] + f"if is_instance_valid({var_name}) and {var_name}.has_method(" + line[m.end():]
            changed = True
            new_lines.append(line)
            continue
            
        new_lines.append(line)
        
    if changed:
        with open(filepath, 'w') as f:
            f.write('\n'.join(new_lines))
        print(f"Fixed: {filepath}")

for root, _, files in os.walk(directory):
    for f in files:
        if f.endswith('.gd'):
            process_file(os.path.join(root, f))
