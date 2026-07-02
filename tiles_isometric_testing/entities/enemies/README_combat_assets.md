# Enemy Unit Assets - Dynamic Slicing & 2x2 Grid Footprints

This directory contains the base unit scenes and scripts. We have refactored the enemy system to be **100% data-driven** (no duplicate copy-paste scenes). All assets, stats, and configurations are loaded dynamically at runtime from [enemies.json](file:///c:/Project-T/Project-T/tiles_isometric_testing/data/stat_module/entity_base_stats/enemies.json).

---

## 🎨 1. Dynamic Spritesheet Slicer (No Hardcoding)
To use custom spritesheet files (like the Mosquito, Grasshopper, or Beetle) without splitting them into separate files manually, you can configure them directly in `enemies.json`.

The unit script [BaseEnemy.gd](file:///c:/Project-T/Project-T/tiles_isometric_testing/entities/enemies/BaseEnemy.gd) parses the `"sprite_animations"` block, crops the frames into memory using `AtlasTexture`, and configures the `SpriteFrames` dynamically.

### How to configure animations in JSON:
Add the following blocks to the enemy entry in `enemies.json`:
```json
"sprite_folder": "res://assets/characters/small_mosquito",
"sprite_animations": {
  "idle": { "file": "enemy small idle.png", "frame_w": 512, "frame_h": 512, "cols": 6, "rows": 1, "frames": 6 },
  "attack": { "file": "enemy small attack.png", "frame_w": 512, "frame_h": 512, "cols": 13, "rows": 1, "frames": 13 },
  "damage": { "file": "small enemy damage.png", "frame_w": 1024, "frame_h": 1054, "cols": 10, "rows": 1, "frames": 10 },
  "mati": { "file": "small enemy mati.png", "frame_w": 1024, "frame_h": 1024, "cols": 10, "rows": 1, "frames": 10 }
}
```
* **`file`**: The filename inside the `sprite_folder`.
* **`frame_w` / `frame_h`**: Width and height of each frame.
* **`cols` / `rows`**: Grid dimensions of the spritesheet (supports both horizontal sheets and grid layouts).
* **`frames`**: Total frames in the sheet to load.

---

## 🧠 2. Ranged AI Brain
For units that require ranged combat (like the Grasshopper), specify `ai_behavior = 1` or configure them with `SimpleRangedBrain.tres` in their scene or JSON stats.
