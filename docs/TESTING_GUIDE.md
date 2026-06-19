# Game Features Testing Guide

This guide outlines how to test the various implemented systems in the game directly within Godot. The test scripts are designed to output their results to the Godot Editor Console (Output panel).

## 🚀 The Fastest Way: Universal Test Shortcut (T)
We have integrated all tests directly into the `main.tscn` debug menu!

1. Open `res://main/Main.tscn` in the Godot Editor.
2. Press **`F6`** to play the scene.
3. While playing, simply press the **`T`** key on your keyboard.
4. **All tests** (Roguelite Systems & Combat Core) will run immediately, and the results will print to your Godot Output console!

---

## 1. Roguelite Run System (Ilham's Features)
This test suite covers the Node Graph generation, Path Traversal, Item/Balancing Pool, Shop Economy, and Luck Events.

**Location:** `d:\Project-T\tiles_isometric_testing\testing\RoguelikeTester.gd`

### How to test:
**Method A: Inside Godot Editor (Recommended)**
1. Open the Godot Editor and navigate to `res://testing/` in the FileSystem dock.
2. Right-click the `RoguelikeTester.gd` script.
3. Select **"Run"** from the context menu.
4. Open the **Output** panel at the bottom of the editor to view the simulated results.

**Method B: Command Line (Headless)**
Since the script extends `SceneTree`, you can run it via command line without opening the Godot UI:
```bash
godot --headless -s d:\Project-T\tiles_isometric_testing\testing\RoguelikeTester.gd
```

---

## 2. Combat Core System (Tapip's Features)
This test suite covers the Action Economy, RNG Dice Roller, and the Turn Phase Manager.

**Location:** `d:\Project-T\tiles_isometric_testing\combat_core\tests\`

### Available Test Scripts:
*   `test_action_economy.gd` - Tests Action Points, Bonus AP, and Energy/Spell Slot consumption.
*   `test_dice_roller.gd` - Tests the D20 hit/miss logic and multi-dice damage/heal rolling.
*   `test_phase_manager.gd` - Tests the transition between concurrent Player Phases and sequential Enemy Phases.

### How to test:
**Method A: Individual Script Testing**
1. Navigate to `res://combat_core/tests/` in the Godot Editor.
2. Right-click any of the `test_*.gd` scripts.
3. Select **"Run"** to execute that specific unit test and check the Output console.

**Method B: Scene Testing**
1. Open the `test.tscn` scene located in the same folder (`res://combat_core/tests/test.tscn`).
2. Press `F6` (Play Current Scene) to run the integrated combat tests.

---

## 3. General Testing Tips
*   **Reading Outputs:** Look for `print()` statements in the Output console. Simulated errors or failed tests will typically show up in red or have `[FAILED]` tags depending on how the scripts are written.
*   **Modifying Tests:** You can easily open any of the `.gd` test files and change variables (e.g., increase the starting coins in `RoguelikeTester.gd`) to see how the systems react to edge cases!
