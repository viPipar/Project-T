# Illustrator Assets Map (illustrator_assets.md)

This document maps the art assets provided by the illustrator team to their corresponding runtime components and locations in the Godot project.

---

## 1. Asset Directory Mapping

| Structured Folder | Description | Godot Target / Implementation |
| :--- | :--- | :--- |
| **`assets/characters/`**<br>`medium_grasshopper/`<br>`small_mosquito/`<br>`big_beetle/` | Sprite sheets and PSD source files for enemies. | Loaded by enemy nodes spawned under `res://entities/enemies/` (Goblin Mosquito, Orc Grasshopper, Elite Beetle). |
| **`assets/characters/`**<br>`p1_fighter/`<br>`p2_wizard/` | Sprite sheets and idle/attack animations for players. | Used by player nodes spawned under `res://entities/player/` (Aria the Fighter, Kael the Wizard). |
| **`assets/ui_assets/skill_icons/`**<br>`p1/`<br>`p2/` | Action icons representing physical and magical abilities. | Bound to ability resources (`BaseAbility.tres`) under `res://combat_core/abilities/instances/`. |
| **`assets/ui_assets/projectiles/`** | Sprite frames and trajectories for ranged projectile impacts. | Used by the projectile spawner under `res://components/GridProjectile.gd`. |
| **`assets/ui_assets/vfx/`**<br>`fighter/`<br>`wizard/` | Particles and overlay textures for hit impacts and status effects. | Configured on status visualizers (`res://components/StatusVisualizerComponent.gd`) and damage popup triggers. |
| **`assets/ui_assets/item_icons/`**<br>`common/`, `rare/`, `epic/`, `legendary/`, `page_of/` | Rarity-themed icons for items, gears, and curses. | Connected to items handled by the registry (`res://systems/items/ItemRegistry.gd`). |
| **`assets/backgrounds/`**<br>`scene_1/` to `scene_5/` | Level parallax blocks, mountains, and sun background plates. | Loaded by the Grid Manager for building maps (`res://world/mapping_grid/`). |
| **`assets/ui_assets/boss_silhouette.png`** | Silhouette image for boss transitions or contested loot events. | Applied in the Contested Pick Overlay in `res://ui/roguelike/LootScreen.tscn`. |

---

## 2. Integration Best Practices

1. **Sprite Scaling**: Standard grid tiles are 256x128. Sprite layouts for characters should maintain proportion to fit standard isometric coordinates.
2. **Animation Sheets**: Keep sheets in standard grid sizes and name frames sequentially (`idle_0`, `idle_1`, etc.) so they map easily to Godot's `AnimatedSprite2D` or `AnimationPlayer` state machines.
3. **UI Assets**: Radial icons should be square and centered, optimized for the Neobrutalist flat shadow formatting wrapper.
