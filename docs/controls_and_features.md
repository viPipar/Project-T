# Action Wheel Integration & Controls Overhaul

We've completely overhauled the input system and successfully migrated the Action Wheel from a standalone test scene directly into your main gameplay loop. Here is a comprehensive breakdown of everything we've implemented.

## 1. Global Input Map Layout

The `project.godot` input map has been entirely rewritten to match your exact split-screen keyboard layout:

| Action | Player 1 (Left Side) | Player 2 (Right Side) |
| :--- | :--- | :--- |
| **Move Up / Wheel Up** | `W` | `I` |
| **Move Left / Wheel Left** | `A` | `J` |
| **Move Down / Wheel Down** | `S` | `K` |
| **Move Right / Wheel Right** | `D` | `L` |
| **Confirm Action** | `F` | `;` (Semicolon) |
| **Cancel / Close Menu** | `X` | `,` (Comma) |
| **Open Menu / Ability 1** | `Q` | `U` |
| **Open Menu / Ability 2** | `E` | `O` |
| **End Turn** | `R` | `P` |
| **Inventory** | `C` | `.` (Period) |
| **Statistics** | `Z` | `M` |
| **Center Camera** | `Shift` | `Enter` |
| **Pause Menu** | `Escape` or `Backspace` | (Shared) |

---

## 2. Independent Action Wheel System

The Action Wheel overlay is now automatically injected into `Main.tscn` via a top-level `CanvasLayer` (Layer 100). The global `F9` toggle has been completely removed.

**Per-Player Toggles**:
Each player controls their own Action Wheel independently. 
- **Player 1** presses `Q` or `E` to open their wheel.
- **Player 2** presses `U` or `O` to open their wheel.
- *Player 2's Action Wheel is explicitly coded to render empty (no abilities loaded) per your request.*

**Page Flipping & Hold-to-Scroll**:
To prevent conflicts with the Q/E/U/O menu toggles, we removed the old Q/E page turning system. Now, players can navigate through ability pages using their left or right movement keys:
- **Double-tap** `A` (P1) / `J` (P2) to flip to the previous page, or `D` (P1) / `L` (P2) for the next page.
- **Press and Hold** `A`/`J` or `D`/`L` to automatically scroll through pages smoothly.
- **Smooth Transitions**: Page flipping now features a dynamic slide-and-fade carousel animation.
- Single taps will simply hover over the corresponding slot as usual.

**Menu Closing**:
To close the menu, press your respective Cancel button (`X` for P1, `,` for P2).

---

## 3. UI Input Locking (No More Accidental Panning!)

We fixed an issue where navigating the Action Wheel would accidentally pan the camera in the background.

- **`ActionWheel.gd`** now correctly toggles `InputManager.is_in_menu = true` only when the wheel is explicitly visible on screen (checking `is_visible_in_tree()`).
- **`PlayerCamera2D.gd`** now respects `InputManager.is_in_menu`. If any player opens an Action Wheel, camera panning via WASD/IJKL is completely locked out until the menu is closed.

---

## 4. Code & Resource Cleanup

- **Removed Dummy Code**: Stripped out the fake dummy nodes and fake HP drain prints from `ActionWheelTestController.gd`. The wheels now cleanly emit signals that your real `Player.gd` scripts pick up (e.g., `[Player P1] Ability terpilih: rupture`).
- **Resource Path Fixes**: Ran a batch powershell script to fix corrupted `res://tiles_isometric_testing/...` paths inside your ability `.tres` files (such as `divine_departure.tres`), ensuring they all load correctly into the game without throwing "File not found" errors.
- **Inventory Hook**: Updated `SplitScreenManager.gd` to listen for the new `p1_inventory` and `p2_inventory` keys instead of the deleted `open_inventory` binding.
