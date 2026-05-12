# Sudokrement MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable MVP of Sudokrement — an active incremental game where players solve Sudokus to earn coins, buy shop upgrades, unlock skill-tree nodes, and prestige for permanent multipliers — exported to HTML5 and deployed to GitHub Pages.

**Architecture:** Godot 4.x project with GDScript. UI scenes (Main, TopBar, SudokuBoard, NumberPad, BottomTabs) consume game state via autoload singletons (Economy, SkillTree, PrestigeManager, SaveSystem). Components communicate via signals for loose coupling and testability. Logic-only systems are testable headlessly with GdUnit4.

**Tech Stack:** Godot 4.3+ (Flatpak on Bazzite), GDScript, GdUnit4 testing framework, GitHub Actions CI, GitHub Pages hosting.

---

## File Structure

```
project.godot                          # Godot project file
icon.svg                                # Default placeholder icon
scenes/
├── Main.tscn                           # Root scene, holds UI tree
├── ui/
│   ├── TopBar.tscn                     # Coins / Coins-per-sec / Prestige / Timer
│   ├── SudokuBoard.tscn                # 9x9 grid, scales to other sizes
│   ├── NumberPad.tscn                  # 1-9 buttons + Notes-Toggle + Erase
│   └── BottomTabs.tscn                 # Tab container for Shop/Bots/Tree/Prestige
└── tabs/
    ├── ShopTab.tscn                    # Run-scoped consumables
    ├── BotsTab.tscn                    # Idle solver bots
    ├── SkillTreeTab.tscn               # Permanent unlocks via Stars
    └── PrestigeTab.tscn                # Prestige trigger + info
systems/                                # Autoload singletons (pure logic, testable)
├── board.gd                            # Board data class
├── cell.gd                             # Cell data class
├── board_generator.gd                  # Generates valid unique Sudokus
├── validator.gd                        # Cell-correctness + combo detection
├── economy.gd                          # Coin currency, multipliers, combos
├── skill_tree.gd                       # Nodes, prerequisites, effects
├── prestige_manager.gd                 # Reset logic, Stars formula
└── save_system.gd                      # JSON persistence to user://
ui/
├── top_bar.gd                          # Script for TopBar.tscn
├── sudoku_board.gd                     # Script for SudokuBoard.tscn
├── number_pad.gd                       # Script for NumberPad.tscn
└── bottom_tabs.gd                      # Script for BottomTabs.tscn
test/                                   # GdUnit4 tests
├── test_board_generator.gd
├── test_validator.gd
├── test_economy.gd
├── test_skill_tree.gd
├── test_prestige.gd
└── test_save_system.gd
addons/gdUnit4/                         # GdUnit4 plugin (installed via AssetLib)
.github/workflows/
└── deploy.yml                          # CI: test + export + deploy to Pages
export_presets.cfg                      # Web export configuration
```

Each system file is a single autoload singleton with one clear responsibility. UI scripts only call into systems; systems never touch UI directly.

---

## Task 0: Install Godot and Initialize Project

**Files:**
- Create: `project.godot`
- Create: `icon.svg`
- Create: `.gitignore` (already exists, will be extended)

- [ ] **Step 1: Install Godot 4.3+ via Flatpak**

Bazzite uses immutable Fedora — Flatpak is the right install path.

Run:
```bash
flatpak install -y flathub org.godotengine.Godot
flatpak run org.godotengine.Godot --version
```

Expected: prints something like `4.3.stable.official...`

- [ ] **Step 2: Create a shell alias for headless invocation**

Run:
```bash
echo "alias godot='flatpak run org.godotengine.Godot'" >> ~/.bashrc
source ~/.bashrc
godot --version
```

Expected: prints Godot version.

- [ ] **Step 3: Create the project.godot manifest**

Create `/var/mnt/Linux_NVME/game/project.godot`:

```ini
; Engine configuration file.
config_version=5

[application]
config/name="Sudokrement"
run/main_scene="res://scenes/Main.tscn"
config/features=PackedStringArray("4.3", "GL Compatibility")
config/icon="res://icon.svg"

[display]
window/size/viewport_width=1024
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

- [ ] **Step 4: Create a placeholder icon**

Create `/var/mnt/Linux_NVME/game/icon.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <rect width="128" height="128" fill="#0f0f0f"/>
  <text x="64" y="80" font-size="64" text-anchor="middle" fill="#fff" font-family="monospace">9</text>
</svg>
```

- [ ] **Step 5: Open the project once so Godot generates .godot/ cache**

Run:
```bash
godot --headless --quit
```

Expected: exits cleanly. Creates `.godot/` cache directory.

- [ ] **Step 6: Commit**

```bash
git add project.godot icon.svg .gitignore
git commit -m "chore: initialize Godot project"
```

---

## Task 1: Install GdUnit4 Testing Framework

**Files:**
- Create: `addons/gdUnit4/` (via plugin download)
- Modify: `project.godot` (enable plugin)

- [ ] **Step 1: Download GdUnit4 latest release**

Run:
```bash
cd /var/mnt/Linux_NVME/game
mkdir -p addons
curl -L -o /tmp/gdunit4.zip https://github.com/MikeSchulze/gdUnit4/releases/latest/download/gdUnit4.zip
unzip -q /tmp/gdunit4.zip -d /tmp/gdunit4-extract
cp -r /tmp/gdunit4-extract/addons/gdUnit4 addons/
ls addons/gdUnit4/bin/
```

Expected: shows `GdUnitCmdTool.gd` among files.

- [ ] **Step 2: Enable the plugin in project.godot**

Append to `project.godot`:

```ini

[editor_plugins]
enabled=PackedStringArray("res://addons/gdUnit4/plugin.cfg")
```

- [ ] **Step 3: Verify GdUnit4 loads**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --help
```

Expected: prints GdUnit4 CLI help (commands like `--run-tests`).

- [ ] **Step 4: Commit**

```bash
git add addons/gdUnit4 project.godot
git commit -m "chore: add GdUnit4 testing framework"
```

---

## Task 2: Cell and Board Data Classes

**Files:**
- Create: `systems/cell.gd`
- Create: `systems/board.gd`
- Create: `test/test_board.gd`

- [ ] **Step 1: Write the failing test**

Create `/var/mnt/Linux_NVME/game/test/test_board.gd`:

```gdscript
extends GdUnitTestSuite

func test_board_initializes_empty_9x9():
    var board = Board.new(9)
    assert_int(board.size).is_equal(9)
    assert_int(board.cells.size()).is_equal(9)
    assert_int(board.cells[0].size()).is_equal(9)
    assert_int(board.cells[0][0].value).is_equal(0)
    assert_bool(board.cells[0][0].given).is_equal(false)

func test_set_cell_updates_value():
    var board = Board.new(9)
    board.set_value(0, 0, 5)
    assert_int(board.cells[0][0].value).is_equal(5)

func test_given_cells_are_immutable():
    var board = Board.new(9)
    board.cells[0][0].given = true
    board.cells[0][0].value = 3
    board.set_value(0, 0, 7)
    assert_int(board.cells[0][0].value).is_equal(3)
```

- [ ] **Step 2: Run test, expect FAIL**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_board.gd
```

Expected: FAIL — "Board is not defined" or similar.

- [ ] **Step 3: Implement Cell**

Create `/var/mnt/Linux_NVME/game/systems/cell.gd`:

```gdscript
class_name Cell
extends RefCounted

var value: int = 0
var given: bool = false
var notes: Array[int] = []
var locked: bool = false

func _init(initial_value: int = 0, is_given: bool = false) -> void:
    value = initial_value
    given = is_given
```

- [ ] **Step 4: Implement Board**

Create `/var/mnt/Linux_NVME/game/systems/board.gd`:

```gdscript
class_name Board
extends RefCounted

var size: int
var cells: Array          # 2D Array of Cell
var solution: Array        # 2D Array of int (correct values)
var difficulty: String = "easy"
var start_time: float = 0.0
var lives_left: int = 3

func _init(board_size: int) -> void:
    size = board_size
    cells = []
    solution = []
    for r in range(size):
        var row: Array = []
        var sol_row: Array = []
        for c in range(size):
            row.append(Cell.new())
            sol_row.append(0)
        cells.append(row)
        solution.append(sol_row)

func set_value(row: int, col: int, value: int) -> void:
    if cells[row][col].given:
        return
    if cells[row][col].locked:
        return
    cells[row][col].value = value
```

- [ ] **Step 5: Run tests, expect PASS**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_board.gd
```

Expected: all 3 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add systems/cell.gd systems/board.gd test/test_board.gd
git commit -m "feat: Cell and Board data classes with tests"
```

---

## Task 3: Board Generator (9x9 Easy)

**Files:**
- Create: `systems/board_generator.gd`
- Create: `test/test_board_generator.gd`

- [ ] **Step 1: Write the failing test**

Create `/var/mnt/Linux_NVME/game/test/test_board_generator.gd`:

```gdscript
extends GdUnitTestSuite

func test_generates_9x9_board():
    var gen = BoardGenerator.new()
    var board = gen.generate("easy")
    assert_int(board.size).is_equal(9)
    assert_str(board.difficulty).is_equal("easy")

func test_solution_is_complete_and_valid():
    var gen = BoardGenerator.new()
    var board = gen.generate("easy")
    for r in range(9):
        for c in range(9):
            assert_int(board.solution[r][c]).is_between(1, 9)
    # Each row contains 1..9 exactly once
    for r in range(9):
        var seen: Dictionary = {}
        for c in range(9):
            seen[board.solution[r][c]] = true
        assert_int(seen.size()).is_equal(9)
    # Each column 1..9
    for c in range(9):
        var seen: Dictionary = {}
        for r in range(9):
            seen[board.solution[r][c]] = true
        assert_int(seen.size()).is_equal(9)
    # Each 3x3 block 1..9
    for br in range(3):
        for bc in range(3):
            var seen: Dictionary = {}
            for r in range(br * 3, br * 3 + 3):
                for c in range(bc * 3, bc * 3 + 3):
                    seen[board.solution[r][c]] = true
            assert_int(seen.size()).is_equal(9)

func test_easy_has_around_40_givens():
    var gen = BoardGenerator.new()
    var board = gen.generate("easy")
    var givens = 0
    for r in range(9):
        for c in range(9):
            if board.cells[r][c].given:
                givens += 1
    assert_int(givens).is_between(36, 46)

func test_given_cells_have_correct_value():
    var gen = BoardGenerator.new()
    var board = gen.generate("easy")
    for r in range(9):
        for c in range(9):
            if board.cells[r][c].given:
                assert_int(board.cells[r][c].value).is_equal(board.solution[r][c])
```

- [ ] **Step 2: Run test, expect FAIL**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_board_generator.gd
```

Expected: FAIL — BoardGenerator not defined.

- [ ] **Step 3: Implement BoardGenerator**

Create `/var/mnt/Linux_NVME/game/systems/board_generator.gd`:

```gdscript
class_name BoardGenerator
extends RefCounted

const DIFFICULTY_GIVENS: Dictionary = {
    "easy":    [36, 46],
    "medium":  [30, 36],
    "hard":    [25, 30],
    "expert":  [22, 25],
}

var _rng: RandomNumberGenerator

func _init() -> void:
    _rng = RandomNumberGenerator.new()
    _rng.randomize()

func generate(difficulty: String) -> Board:
    var board := Board.new(9)
    board.difficulty = difficulty
    _fill_solution(board)
    _remove_cells(board, difficulty)
    return board

func _fill_solution(board: Board) -> void:
    var grid: Array = []
    for r in range(9):
        var row: Array = []
        for c in range(9):
            row.append(0)
        grid.append(row)
    _solve(grid)
    for r in range(9):
        for c in range(9):
            board.solution[r][c] = grid[r][c]

func _solve(grid: Array) -> bool:
    for r in range(9):
        for c in range(9):
            if grid[r][c] == 0:
                var nums: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9]
                nums.shuffle()
                for n in nums:
                    if _is_safe(grid, r, c, n):
                        grid[r][c] = n
                        if _solve(grid):
                            return true
                        grid[r][c] = 0
                return false
    return true

func _is_safe(grid: Array, row: int, col: int, n: int) -> bool:
    for i in range(9):
        if grid[row][i] == n:
            return false
        if grid[i][col] == n:
            return false
    var br := (row / 3) * 3
    var bc := (col / 3) * 3
    for r in range(br, br + 3):
        for c in range(bc, bc + 3):
            if grid[r][c] == n:
                return false
    return true

func _remove_cells(board: Board, difficulty: String) -> void:
    var range_arr: Array = DIFFICULTY_GIVENS.get(difficulty, [36, 46])
    var target_givens: int = _rng.randi_range(range_arr[0], range_arr[1])
    var positions: Array = []
    for r in range(9):
        for c in range(9):
            positions.append(Vector2i(r, c))
    positions.shuffle()
    var givens: Array = positions.slice(0, target_givens)
    for pos in givens:
        board.cells[pos.x][pos.y].value = board.solution[pos.x][pos.y]
        board.cells[pos.x][pos.y].given = true
```

Note: For MVP simplicity we don't enforce uniqueness via solver-based verification. The backtracking generator + random removal almost always produces solvable boards. Uniqueness check can be added later if needed.

- [ ] **Step 4: Run tests, expect PASS**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_board_generator.gd
```

Expected: all 4 tests PASS. May take 1–2 seconds per generation.

- [ ] **Step 5: Commit**

```bash
git add systems/board_generator.gd test/test_board_generator.gd
git commit -m "feat: BoardGenerator with backtracking + difficulty tiers"
```

---

## Task 4: Validator with Combo Detection

**Files:**
- Create: `systems/validator.gd`
- Create: `test/test_validator.gd`

- [ ] **Step 1: Write the failing test**

Create `/var/mnt/Linux_NVME/game/test/test_validator.gd`:

```gdscript
extends GdUnitTestSuite

func _make_board_with_solution() -> Board:
    var b := Board.new(9)
    for r in range(9):
        for c in range(9):
            b.solution[r][c] = ((r * 3 + r / 3 + c) % 9) + 1
    return b

func test_correct_cell_returns_true():
    var v := Validator.new()
    var b := _make_board_with_solution()
    assert_bool(v.is_correct(b, 0, 0, b.solution[0][0])).is_equal(true)

func test_incorrect_cell_returns_false():
    var v := Validator.new()
    var b := _make_board_with_solution()
    var wrong := (b.solution[0][0] % 9) + 1
    assert_bool(v.is_correct(b, 0, 0, wrong)).is_equal(false)

func test_completed_row_is_detected():
    var v := Validator.new()
    var b := _make_board_with_solution()
    for c in range(9):
        b.cells[0][c].value = b.solution[0][c]
    assert_bool(v.is_row_complete(b, 0)).is_equal(true)
    assert_bool(v.is_row_complete(b, 1)).is_equal(false)

func test_completed_column_is_detected():
    var v := Validator.new()
    var b := _make_board_with_solution()
    for r in range(9):
        b.cells[r][0].value = b.solution[r][0]
    assert_bool(v.is_column_complete(b, 0)).is_equal(true)

func test_completed_block_is_detected():
    var v := Validator.new()
    var b := _make_board_with_solution()
    for r in range(3):
        for c in range(3):
            b.cells[r][c].value = b.solution[r][c]
    assert_bool(v.is_block_complete(b, 0, 0)).is_equal(true)

func test_board_complete_only_when_all_correct():
    var v := Validator.new()
    var b := _make_board_with_solution()
    assert_bool(v.is_board_complete(b)).is_equal(false)
    for r in range(9):
        for c in range(9):
            b.cells[r][c].value = b.solution[r][c]
    assert_bool(v.is_board_complete(b)).is_equal(true)
```

- [ ] **Step 2: Run test, expect FAIL**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_validator.gd
```

Expected: FAIL — Validator not defined.

- [ ] **Step 3: Implement Validator**

Create `/var/mnt/Linux_NVME/game/systems/validator.gd`:

```gdscript
class_name Validator
extends RefCounted

func is_correct(board: Board, row: int, col: int, value: int) -> bool:
    return board.solution[row][col] == value

func is_row_complete(board: Board, row: int) -> bool:
    for c in range(board.size):
        if board.cells[row][c].value != board.solution[row][c]:
            return false
    return true

func is_column_complete(board: Board, col: int) -> bool:
    for r in range(board.size):
        if board.cells[r][col].value != board.solution[r][col]:
            return false
    return true

func is_block_complete(board: Board, row: int, col: int) -> bool:
    var br := (row / 3) * 3
    var bc := (col / 3) * 3
    for r in range(br, br + 3):
        for c in range(bc, bc + 3):
            if board.cells[r][c].value != board.solution[r][c]:
                return false
    return true

func is_board_complete(board: Board) -> bool:
    for r in range(board.size):
        for c in range(board.size):
            if board.cells[r][c].value != board.solution[r][c]:
                return false
    return true
```

- [ ] **Step 4: Run tests, expect PASS**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_validator.gd
```

Expected: all 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add systems/validator.gd test/test_validator.gd
git commit -m "feat: Validator with row/column/block/board completion detection"
```

---

## Task 5: Economy Singleton with Coin Awards

**Files:**
- Create: `systems/economy.gd`
- Create: `test/test_economy.gd`
- Modify: `project.godot` (register autoload)

- [ ] **Step 1: Write the failing test**

Create `/var/mnt/Linux_NVME/game/test/test_economy.gd`:

```gdscript
extends GdUnitTestSuite

var economy: Node

func before_test() -> void:
    economy = load("res://systems/economy.gd").new()
    add_child(economy)
    economy.reset()

func test_starts_with_zero_coins():
    assert_int(economy.coins).is_equal(0)

func test_award_cell_grants_base_coins():
    economy.award_cell()
    assert_int(economy.coins).is_equal(1)

func test_difficulty_multiplier_applies():
    economy.difficulty_mode = "standard"
    economy.award_cell()
    assert_float(economy.coins).is_equal_approx(1.5, 0.01)

func test_hardcore_multiplier():
    economy.difficulty_mode = "hardcore"
    economy.award_cell()
    assert_float(economy.coins).is_equal_approx(2.5, 0.01)

func test_combo_row_grants_bonus():
    var before := economy.coins
    economy.award_combo("row")
    assert_float(economy.coins - before).is_equal_approx(10.0, 0.01)

func test_combo_block_grants_bonus():
    var before := economy.coins
    economy.award_combo("block")
    assert_float(economy.coins - before).is_equal_approx(20.0, 0.01)

func test_board_complete_bonus():
    var before := economy.coins
    economy.award_board_complete(0.0)
    assert_float(economy.coins - before).is_equal_approx(100.0, 0.01)

func test_permanent_multiplier_stacks():
    economy.permanent_multiplier = 2.0
    economy.award_cell()
    assert_float(economy.coins).is_equal_approx(2.0, 0.01)

func test_coins_changed_signal_fires():
    var monitor = monitor_signals(economy)
    economy.award_cell()
    await assert_signal(monitor).is_emitted("coins_changed")
```

- [ ] **Step 2: Run test, expect FAIL**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_economy.gd
```

Expected: FAIL — Economy not defined / missing methods.

- [ ] **Step 3: Implement Economy**

Create `/var/mnt/Linux_NVME/game/systems/economy.gd`:

```gdscript
extends Node

signal coins_changed(new_total: float)

const DIFFICULTY_MULT: Dictionary = {
    "casual":   1.0,
    "standard": 1.5,
    "hardcore": 2.5,
}

const COMBO_BONUS: Dictionary = {
    "row":    10.0,
    "column": 10.0,
    "block":  20.0,
}

const BOARD_COMPLETE_BONUS: float = 100.0

var coins: float = 0.0
var permanent_multiplier: float = 1.0
var run_multiplier: float = 1.0
var difficulty_mode: String = "casual"

func reset() -> void:
    coins = 0.0
    run_multiplier = 1.0
    coins_changed.emit(coins)

func _effective_multiplier() -> float:
    return DIFFICULTY_MULT.get(difficulty_mode, 1.0) * permanent_multiplier * run_multiplier

func award_cell() -> void:
    coins += 1.0 * _effective_multiplier()
    coins_changed.emit(coins)

func award_combo(combo_type: String) -> void:
    var bonus: float = COMBO_BONUS.get(combo_type, 0.0)
    coins += bonus * _effective_multiplier()
    coins_changed.emit(coins)

func award_board_complete(speed_bonus: float) -> void:
    coins += (BOARD_COMPLETE_BONUS + speed_bonus) * _effective_multiplier()
    coins_changed.emit(coins)
```

- [ ] **Step 4: Register Economy as autoload**

Append to `project.godot`:

```ini

[autoload]
Economy="*res://systems/economy.gd"
```

(The `*` prefix means the singleton is also accessible as a global.)

- [ ] **Step 5: Run tests, expect PASS**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_economy.gd
```

Expected: all 9 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add systems/economy.gd test/test_economy.gd project.godot
git commit -m "feat: Economy autoload with cell/combo/board rewards"
```

---

## Task 6: Sudoku Board Scene with Click-to-Select

**Files:**
- Create: `scenes/ui/SudokuBoard.tscn`
- Create: `ui/sudoku_board.gd`

- [ ] **Step 1: Create the SudokuBoard scene**

Create `/var/mnt/Linux_NVME/game/scenes/ui/SudokuBoard.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/sudoku_board.gd" id="1"]

[node name="SudokuBoard" type="GridContainer"]
columns = 9
script = ExtResource("1")
custom_minimum_size = Vector2(450, 450)
```

- [ ] **Step 2: Implement sudoku_board.gd**

Create `/var/mnt/Linux_NVME/game/ui/sudoku_board.gd`:

```gdscript
extends GridContainer

signal cell_selected(row: int, col: int)
signal cell_filled(row: int, col: int, value: int, is_correct: bool)

const CELL_SIZE: Vector2 = Vector2(48, 48)

var board: Board
var validator: Validator
var selected_row: int = -1
var selected_col: int = -1
var _cell_buttons: Array = []

func _ready() -> void:
    validator = Validator.new()

func set_board(new_board: Board) -> void:
    board = new_board
    columns = board.size
    _rebuild_grid()

func _rebuild_grid() -> void:
    for child in get_children():
        child.queue_free()
    _cell_buttons.clear()
    for r in range(board.size):
        var row_btns: Array = []
        for c in range(board.size):
            var btn := Button.new()
            btn.custom_minimum_size = CELL_SIZE
            btn.flat = false
            _update_button(btn, r, c)
            btn.pressed.connect(_on_cell_pressed.bind(r, c))
            add_child(btn)
            row_btns.append(btn)
        _cell_buttons.append(row_btns)

func _update_button(btn: Button, r: int, c: int) -> void:
    var cell: Cell = board.cells[r][c]
    if cell.value > 0:
        btn.text = str(cell.value)
    else:
        btn.text = ""
    if cell.given:
        btn.modulate = Color(0.7, 0.7, 1.0)
    else:
        btn.modulate = Color(1.0, 1.0, 1.0)

func _on_cell_pressed(row: int, col: int) -> void:
    selected_row = row
    selected_col = col
    cell_selected.emit(row, col)

func input_value(value: int) -> void:
    if selected_row < 0 or selected_col < 0:
        return
    if board.cells[selected_row][selected_col].given:
        return
    board.set_value(selected_row, selected_col, value)
    var correct: bool = validator.is_correct(board, selected_row, selected_col, value)
    _update_button(_cell_buttons[selected_row][selected_col], selected_row, selected_col)
    cell_filled.emit(selected_row, selected_col, value, correct)
```

- [ ] **Step 3: Commit**

```bash
git add scenes/ui/SudokuBoard.tscn ui/sudoku_board.gd
git commit -m "feat: SudokuBoard scene with click-to-select cells"
```

---

## Task 7: Number Pad Scene with Keyboard Input

**Files:**
- Create: `scenes/ui/NumberPad.tscn`
- Create: `ui/number_pad.gd`

- [ ] **Step 1: Create NumberPad scene**

Create `/var/mnt/Linux_NVME/game/scenes/ui/NumberPad.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/number_pad.gd" id="1"]

[node name="NumberPad" type="HBoxContainer"]
script = ExtResource("1")
```

- [ ] **Step 2: Implement number_pad.gd**

Create `/var/mnt/Linux_NVME/game/ui/number_pad.gd`:

```gdscript
extends HBoxContainer

signal number_pressed(value: int)
signal erase_pressed()

const BUTTON_SIZE: Vector2 = Vector2(44, 44)

func _ready() -> void:
    for n in range(1, 10):
        var btn := Button.new()
        btn.text = str(n)
        btn.custom_minimum_size = BUTTON_SIZE
        btn.pressed.connect(_on_number.bind(n))
        add_child(btn)
    var erase := Button.new()
    erase.text = "X"
    erase.custom_minimum_size = BUTTON_SIZE
    erase.pressed.connect(_on_erase)
    add_child(erase)

func _on_number(value: int) -> void:
    number_pressed.emit(value)

func _on_erase() -> void:
    erase_pressed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    if not event.pressed:
        return
    var key: int = event.keycode
    if key >= KEY_1 and key <= KEY_9:
        number_pressed.emit(key - KEY_0)
        get_viewport().set_input_as_handled()
    elif key == KEY_BACKSPACE or key == KEY_DELETE or key == KEY_0:
        erase_pressed.emit()
        get_viewport().set_input_as_handled()
```

- [ ] **Step 3: Commit**

```bash
git add scenes/ui/NumberPad.tscn ui/number_pad.gd
git commit -m "feat: NumberPad with button + keyboard input"
```

---

## Task 8: TopBar Scene with Live Coin Display

**Files:**
- Create: `scenes/ui/TopBar.tscn`
- Create: `ui/top_bar.gd`

- [ ] **Step 1: Create TopBar scene**

Create `/var/mnt/Linux_NVME/game/scenes/ui/TopBar.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/top_bar.gd" id="1"]

[node name="TopBar" type="HBoxContainer"]
script = ExtResource("1")
custom_minimum_size = Vector2(0, 40)

[node name="CoinsLabel" type="Label" parent="."]
text = "Coins: 0"

[node name="Spacer1" type="Control" parent="."]
size_flags_horizontal = 3

[node name="PrestigeLabel" type="Label" parent="."]
text = "Prestige: 0"

[node name="Spacer2" type="Control" parent="."]
size_flags_horizontal = 3

[node name="TimerLabel" type="Label" parent="."]
text = "00:00"
```

- [ ] **Step 2: Implement top_bar.gd**

Create `/var/mnt/Linux_NVME/game/ui/top_bar.gd`:

```gdscript
extends HBoxContainer

@onready var coins_label: Label = $CoinsLabel
@onready var prestige_label: Label = $PrestigeLabel
@onready var timer_label: Label = $TimerLabel

var _elapsed: float = 0.0

func _ready() -> void:
    Economy.coins_changed.connect(_on_coins_changed)
    _on_coins_changed(Economy.coins)

func _process(delta: float) -> void:
    _elapsed += delta
    var m: int = int(_elapsed) / 60
    var s: int = int(_elapsed) % 60
    timer_label.text = "%02d:%02d" % [m, s]

func _on_coins_changed(new_total: float) -> void:
    coins_label.text = "Coins: %d" % int(new_total)

func reset_timer() -> void:
    _elapsed = 0.0
```

- [ ] **Step 3: Commit**

```bash
git add scenes/ui/TopBar.tscn ui/top_bar.gd
git commit -m "feat: TopBar with live coin display and elapsed timer"
```

---

## Task 9: Main Scene Wiring Everything Together

**Files:**
- Create: `scenes/Main.tscn`
- Create: `ui/main.gd`

- [ ] **Step 1: Create Main.tscn**

Create `/var/mnt/Linux_NVME/game/scenes/Main.tscn`:

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://ui/main.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/ui/TopBar.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/SudokuBoard.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/ui/NumberPad.tscn" id="4"]

[node name="Main" type="VBoxContainer"]
script = ExtResource("1")
anchor_right = 1.0
anchor_bottom = 1.0

[node name="TopBar" parent="." instance=ExtResource("2")]

[node name="BoardContainer" type="CenterContainer" parent="."]
size_flags_vertical = 3

[node name="SudokuBoard" parent="BoardContainer" instance=ExtResource("3")]

[node name="NumberPadContainer" type="CenterContainer" parent="."]

[node name="NumberPad" parent="NumberPadContainer" instance=ExtResource("4")]
```

- [ ] **Step 2: Implement main.gd**

Create `/var/mnt/Linux_NVME/game/ui/main.gd`:

```gdscript
extends VBoxContainer

@onready var sudoku_board: GridContainer = $BoardContainer/SudokuBoard
@onready var number_pad: HBoxContainer = $NumberPadContainer/NumberPad
@onready var top_bar: HBoxContainer = $TopBar

var validator: Validator
var generator: BoardGenerator

func _ready() -> void:
    validator = Validator.new()
    generator = BoardGenerator.new()
    number_pad.number_pressed.connect(_on_number_pressed)
    number_pad.erase_pressed.connect(_on_erase_pressed)
    sudoku_board.cell_filled.connect(_on_cell_filled)
    _start_new_board()

func _start_new_board() -> void:
    var board := generator.generate("easy")
    sudoku_board.set_board(board)
    top_bar.reset_timer()

func _on_number_pressed(value: int) -> void:
    sudoku_board.input_value(value)

func _on_erase_pressed() -> void:
    sudoku_board.input_value(0)

func _on_cell_filled(row: int, col: int, value: int, is_correct: bool) -> void:
    if not is_correct:
        return
    Economy.award_cell()
    var board: Board = sudoku_board.board
    if validator.is_row_complete(board, row):
        Economy.award_combo("row")
    if validator.is_column_complete(board, col):
        Economy.award_combo("column")
    if validator.is_block_complete(board, row, col):
        Economy.award_combo("block")
    if validator.is_board_complete(board):
        Economy.award_board_complete(0.0)
        _start_new_board()
```

- [ ] **Step 3: Run the game once to verify it boots**

Run:
```bash
godot --path . --headless --quit-after 100
```

Expected: prints "Loaded scene" or similar without errors. (Quits after 100 frames.)

- [ ] **Step 4: Commit**

```bash
git add scenes/Main.tscn ui/main.gd
git commit -m "feat: Main scene wires TopBar, SudokuBoard, NumberPad, Economy"
```

**Checkpoint: At this point the game is playable end-to-end with one difficulty.**

---

## Task 10: SaveSystem with JSON Persistence

**Files:**
- Create: `systems/save_system.gd`
- Create: `test/test_save_system.gd`
- Modify: `project.godot` (register autoload)

- [ ] **Step 1: Write the failing test**

Create `/var/mnt/Linux_NVME/game/test/test_save_system.gd`:

```gdscript
extends GdUnitTestSuite

var save_system: Node

func before_test() -> void:
    save_system = load("res://systems/save_system.gd").new()
    add_child(save_system)
    save_system.save_path = "user://test_save.json"

func after_test() -> void:
    var dir := DirAccess.open("user://")
    if dir and dir.file_exists("test_save.json"):
        dir.remove("test_save.json")

func test_round_trip_preserves_state():
    var data := {
        "version": 1,
        "coins": 1234.5,
        "prestige_count": 2,
        "unlocked_tiers": ["easy", "medium"],
    }
    save_system.save_data(data)
    var loaded: Dictionary = save_system.load_data()
    assert_float(loaded["coins"]).is_equal_approx(1234.5, 0.01)
    assert_int(loaded["prestige_count"]).is_equal(2)
    assert_array(loaded["unlocked_tiers"]).contains_exactly(["easy", "medium"])

func test_load_returns_empty_dict_when_no_save():
    var loaded: Dictionary = save_system.load_data()
    assert_dict(loaded).is_empty()

func test_export_returns_json_string():
    var data := {"coins": 42}
    save_system.save_data(data)
    var json_str: String = save_system.export_as_string()
    assert_str(json_str).contains("42")

func test_import_parses_json_string():
    var json_str := "{\"coins\": 99, \"version\": 1}"
    var success := save_system.import_from_string(json_str)
    assert_bool(success).is_equal(true)
    var loaded: Dictionary = save_system.load_data()
    assert_int(loaded["coins"]).is_equal(99)
```

- [ ] **Step 2: Run test, expect FAIL**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_save_system.gd
```

Expected: FAIL — SaveSystem methods missing.

- [ ] **Step 3: Implement SaveSystem**

Create `/var/mnt/Linux_NVME/game/systems/save_system.gd`:

```gdscript
extends Node

const CURRENT_VERSION: int = 1

var save_path: String = "user://save.json"

func save_data(data: Dictionary) -> void:
    var to_write := data.duplicate(true)
    to_write["version"] = CURRENT_VERSION
    var file := FileAccess.open(save_path, FileAccess.WRITE)
    if file == null:
        push_error("SaveSystem: cannot open " + save_path)
        return
    file.store_string(JSON.stringify(to_write))
    file.close()

func load_data() -> Dictionary:
    if not FileAccess.file_exists(save_path):
        return {}
    var file := FileAccess.open(save_path, FileAccess.READ)
    if file == null:
        return {}
    var text := file.get_as_text()
    file.close()
    var parsed = JSON.parse_string(text)
    if parsed is Dictionary:
        return parsed
    return {}

func export_as_string() -> String:
    var data := load_data()
    return JSON.stringify(data)

func import_from_string(json_str: String) -> bool:
    var parsed = JSON.parse_string(json_str)
    if not (parsed is Dictionary):
        return false
    save_data(parsed)
    return true
```

- [ ] **Step 4: Register as autoload**

Modify `project.godot` autoload section:

```ini
[autoload]
Economy="*res://systems/economy.gd"
SaveSystem="*res://systems/save_system.gd"
```

- [ ] **Step 5: Run tests, expect PASS**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_save_system.gd
```

Expected: all 4 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add systems/save_system.gd test/test_save_system.gd project.godot
git commit -m "feat: SaveSystem with JSON round-trip + export/import"
```

---

## Task 11: Integrate SaveSystem with Game State

**Files:**
- Modify: `ui/main.gd`
- Modify: `systems/economy.gd`

- [ ] **Step 1: Add serialize/deserialize to Economy**

Append to `/var/mnt/Linux_NVME/game/systems/economy.gd`:

```gdscript

func serialize() -> Dictionary:
    return {
        "coins": coins,
        "permanent_multiplier": permanent_multiplier,
        "difficulty_mode": difficulty_mode,
    }

func deserialize(data: Dictionary) -> void:
    coins = data.get("coins", 0.0)
    permanent_multiplier = data.get("permanent_multiplier", 1.0)
    difficulty_mode = data.get("difficulty_mode", "casual")
    coins_changed.emit(coins)
```

- [ ] **Step 2: Update main.gd to load/save**

Modify `/var/mnt/Linux_NVME/game/ui/main.gd` `_ready()` to load on start and add autosave:

Replace the `_ready` function with:

```gdscript
func _ready() -> void:
    validator = Validator.new()
    generator = BoardGenerator.new()
    number_pad.number_pressed.connect(_on_number_pressed)
    number_pad.erase_pressed.connect(_on_erase_pressed)
    sudoku_board.cell_filled.connect(_on_cell_filled)
    _load_game()
    _start_new_board()
    var autosave := Timer.new()
    autosave.wait_time = 30.0
    autosave.autostart = true
    autosave.timeout.connect(_save_game)
    add_child(autosave)

func _load_game() -> void:
    var data := SaveSystem.load_data()
    if data.has("economy"):
        Economy.deserialize(data["economy"])

func _save_game() -> void:
    SaveSystem.save_data({
        "economy": Economy.serialize(),
    })
```

Also call `_save_game()` after every board complete — replace `_on_cell_filled` last few lines:

```gdscript
    if validator.is_board_complete(board):
        Economy.award_board_complete(0.0)
        _save_game()
        _start_new_board()
```

- [ ] **Step 3: Manual smoke test**

Run:
```bash
godot --path . --headless --quit-after 60
```

Expected: no errors. `user://save.json` (in `~/.local/share/godot/app_userdata/Sudokrement/`) appears after 30s if game ran long enough.

- [ ] **Step 4: Commit**

```bash
git add ui/main.gd systems/economy.gd
git commit -m "feat: integrate SaveSystem with autosave + load on start"
```

---

## Task 12: Difficulty Mode Selector in TopBar

**Files:**
- Modify: `scenes/ui/TopBar.tscn`
- Modify: `ui/top_bar.gd`

- [ ] **Step 1: Add OptionButton to TopBar.tscn**

Add a new node before `Spacer1` in `/var/mnt/Linux_NVME/game/scenes/ui/TopBar.tscn`:

```
[node name="DifficultyButton" type="OptionButton" parent="."]
```

- [ ] **Step 2: Populate and connect in top_bar.gd**

Add to `_ready()` in `/var/mnt/Linux_NVME/game/ui/top_bar.gd`:

```gdscript
    var diff_btn: OptionButton = $DifficultyButton
    diff_btn.add_item("Casual (×1.0)", 0)
    diff_btn.add_item("Standard (×1.5)", 1)
    diff_btn.add_item("Hardcore (×2.5)", 2)
    diff_btn.item_selected.connect(_on_difficulty_changed)
    var modes := ["casual", "standard", "hardcore"]
    diff_btn.select(modes.find(Economy.difficulty_mode))
```

Add new function:

```gdscript
func _on_difficulty_changed(index: int) -> void:
    var modes := ["casual", "standard", "hardcore"]
    Economy.difficulty_mode = modes[index]
```

- [ ] **Step 3: Smoke test**

Run:
```bash
godot --path . --headless --quit-after 30
```

Expected: no errors, OptionButton initializes.

- [ ] **Step 4: Commit**

```bash
git add scenes/ui/TopBar.tscn ui/top_bar.gd
git commit -m "feat: difficulty mode selector in TopBar"
```

---

## Task 13: BottomTabs and ShopTab Scaffold

**Files:**
- Create: `scenes/ui/BottomTabs.tscn`
- Create: `ui/bottom_tabs.gd`
- Create: `scenes/tabs/ShopTab.tscn`
- Create: `ui/shop_tab.gd`
- Modify: `scenes/Main.tscn`
- Modify: `ui/main.gd`

- [ ] **Step 1: Create BottomTabs scene**

Create `/var/mnt/Linux_NVME/game/scenes/ui/BottomTabs.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://ui/bottom_tabs.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/tabs/ShopTab.tscn" id="2"]

[node name="BottomTabs" type="TabContainer"]
script = ExtResource("1")
custom_minimum_size = Vector2(0, 200)

[node name="Shop" parent="." instance=ExtResource("2")]
```

- [ ] **Step 2: Implement bottom_tabs.gd**

Create `/var/mnt/Linux_NVME/game/ui/bottom_tabs.gd`:

```gdscript
extends TabContainer

func _ready() -> void:
    pass
```

- [ ] **Step 3: Create ShopTab scene**

Create `/var/mnt/Linux_NVME/game/scenes/tabs/ShopTab.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/shop_tab.gd" id="1"]

[node name="Shop" type="VBoxContainer"]
script = ExtResource("1")
```

- [ ] **Step 4: Implement shop_tab.gd with Hint item**

Create `/var/mnt/Linux_NVME/game/ui/shop_tab.gd`:

```gdscript
extends VBoxContainer

signal hint_purchased()

const HINT_BASE_COST: float = 50.0
const HINT_COST_SCALING: float = 1.5

var _hint_purchases: int = 0

@onready var hint_button: Button = $HintButton

func _ready() -> void:
    hint_button = Button.new()
    hint_button.text = _hint_label()
    hint_button.pressed.connect(_on_hint_pressed)
    add_child(hint_button)
    Economy.coins_changed.connect(_on_coins_changed)
    _on_coins_changed(Economy.coins)

func _hint_cost() -> float:
    return HINT_BASE_COST * pow(HINT_COST_SCALING, _hint_purchases)

func _hint_label() -> String:
    return "Hint (+1 cell) — %d coins" % int(_hint_cost())

func _on_coins_changed(total: float) -> void:
    hint_button.disabled = total < _hint_cost()
    hint_button.text = _hint_label()

func _on_hint_pressed() -> void:
    var cost := _hint_cost()
    if Economy.coins < cost:
        return
    Economy.coins -= cost
    Economy.coins_changed.emit(Economy.coins)
    _hint_purchases += 1
    hint_purchased.emit()
```

- [ ] **Step 5: Modify Main.tscn to include BottomTabs**

Append to `/var/mnt/Linux_NVME/game/scenes/Main.tscn` ext_resources and nodes:

```
[ext_resource type="PackedScene" path="res://scenes/ui/BottomTabs.tscn" id="5"]
```

And add at the bottom of the node list:

```
[node name="BottomTabs" parent="." instance=ExtResource("5")]
```

- [ ] **Step 6: Wire hint_purchased to reveal cell in main.gd**

Add to `_ready()`:

```gdscript
    var bottom_tabs: TabContainer = $BottomTabs
    var shop: VBoxContainer = bottom_tabs.get_node("Shop")
    shop.hint_purchased.connect(_on_hint_purchased)
```

Add function to `/var/mnt/Linux_NVME/game/ui/main.gd`:

```gdscript
func _on_hint_purchased() -> void:
    var board: Board = sudoku_board.board
    var empty_cells: Array = []
    for r in range(board.size):
        for c in range(board.size):
            if board.cells[r][c].value == 0:
                empty_cells.append(Vector2i(r, c))
    if empty_cells.is_empty():
        return
    empty_cells.shuffle()
    var pos: Vector2i = empty_cells[0]
    board.cells[pos.x][pos.y].value = board.solution[pos.x][pos.y]
    board.cells[pos.x][pos.y].locked = true
    sudoku_board._rebuild_grid()
```

- [ ] **Step 7: Commit**

```bash
git add scenes/ui/BottomTabs.tscn ui/bottom_tabs.gd scenes/tabs/ShopTab.tscn ui/shop_tab.gd scenes/Main.tscn ui/main.gd
git commit -m "feat: BottomTabs with ShopTab and Hint item"
```

---

## Task 14: SkillTree Singleton

**Files:**
- Create: `systems/skill_tree.gd`
- Create: `test/test_skill_tree.gd`
- Modify: `project.godot`

- [ ] **Step 1: Write the failing test**

Create `/var/mnt/Linux_NVME/game/test/test_skill_tree.gd`:

```gdscript
extends GdUnitTestSuite

var tree: Node

func before_test() -> void:
    tree = load("res://systems/skill_tree.gd").new()
    add_child(tree)
    tree.reset()

func test_starts_with_no_nodes_unlocked():
    assert_bool(tree.is_unlocked("naked_single")).is_equal(false)

func test_starts_with_zero_stars():
    assert_int(tree.stars).is_equal(0)

func test_unlock_requires_enough_stars():
    var ok: bool = tree.unlock("naked_single")
    assert_bool(ok).is_equal(false)

func test_unlock_succeeds_when_stars_available():
    tree.stars = 5
    var ok: bool = tree.unlock("naked_single")
    assert_bool(ok).is_equal(true)
    assert_bool(tree.is_unlocked("naked_single")).is_equal(true)
    assert_int(tree.stars).is_equal(4)

func test_unlock_blocked_by_prerequisite():
    tree.stars = 10
    var ok: bool = tree.unlock("hidden_single")
    assert_bool(ok).is_equal(false)

func test_unlock_succeeds_with_prerequisite():
    tree.stars = 10
    tree.unlock("naked_single")
    var ok: bool = tree.unlock("hidden_single")
    assert_bool(ok).is_equal(true)
```

- [ ] **Step 2: Run test, expect FAIL**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_skill_tree.gd
```

Expected: FAIL.

- [ ] **Step 3: Implement SkillTree**

Create `/var/mnt/Linux_NVME/game/systems/skill_tree.gd`:

```gdscript
extends Node

signal node_unlocked(node_id: String)
signal stars_changed(new_total: int)

const NODES: Dictionary = {
    "naked_single":  {"cost": 1, "requires": [], "branch": "solvers"},
    "hidden_single": {"cost": 2, "requires": ["naked_single"], "branch": "solvers"},
    "pointing_pair": {"cost": 3, "requires": ["hidden_single"], "branch": "solvers"},
    "coin_plus_10":  {"cost": 2, "requires": [], "branch": "economy"},
    "combo_1_5x":    {"cost": 3, "requires": ["coin_plus_10"], "branch": "economy"},
    "tier_medium":   {"cost": 5, "requires": [], "branch": "progression"},
    "tier_hard":     {"cost": 10, "requires": ["tier_medium"], "branch": "progression"},
}

var stars: int = 0
var unlocked: Dictionary = {}

func reset() -> void:
    stars = 0
    unlocked.clear()
    stars_changed.emit(stars)

func is_unlocked(node_id: String) -> bool:
    return unlocked.get(node_id, false) == true

func can_unlock(node_id: String) -> bool:
    if is_unlocked(node_id):
        return false
    var node: Dictionary = NODES.get(node_id, {})
    if node.is_empty():
        return false
    if stars < node["cost"]:
        return false
    for req in node["requires"]:
        if not is_unlocked(req):
            return false
    return true

func unlock(node_id: String) -> bool:
    if not can_unlock(node_id):
        return false
    var node: Dictionary = NODES[node_id]
    stars -= node["cost"]
    unlocked[node_id] = true
    node_unlocked.emit(node_id)
    stars_changed.emit(stars)
    return true

func add_stars(amount: int) -> void:
    stars += amount
    stars_changed.emit(stars)

func serialize() -> Dictionary:
    return {"stars": stars, "unlocked": unlocked.duplicate()}

func deserialize(data: Dictionary) -> void:
    stars = data.get("stars", 0)
    unlocked = data.get("unlocked", {}).duplicate()
    stars_changed.emit(stars)
```

- [ ] **Step 4: Register autoload**

Update autoload section in `project.godot`:

```ini
[autoload]
Economy="*res://systems/economy.gd"
SaveSystem="*res://systems/save_system.gd"
SkillTree="*res://systems/skill_tree.gd"
```

- [ ] **Step 5: Run tests, expect PASS**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_skill_tree.gd
```

Expected: all 6 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add systems/skill_tree.gd test/test_skill_tree.gd project.godot
git commit -m "feat: SkillTree autoload with nodes, prerequisites, costs"
```

---

## Task 15: PrestigeManager with Stars Formula

**Files:**
- Create: `systems/prestige_manager.gd`
- Create: `test/test_prestige.gd`
- Modify: `project.godot`

- [ ] **Step 1: Write the failing test**

Create `/var/mnt/Linux_NVME/game/test/test_prestige.gd`:

```gdscript
extends GdUnitTestSuite

var pm: Node

func before_test() -> void:
    pm = load("res://systems/prestige_manager.gd").new()
    add_child(pm)
    pm.reset()
    Economy.reset()
    SkillTree.reset()

func test_stars_formula():
    pm.lifetime_coins = 4000.0
    var stars: int = pm.calculate_stars()
    assert_int(stars).is_equal(2)  # floor(sqrt(4000/1000)) = floor(2.0) = 2

func test_zero_when_under_threshold():
    pm.lifetime_coins = 500.0
    assert_int(pm.calculate_stars()).is_equal(0)

func test_prestige_requires_25_boards():
    pm.boards_solved_current_tier = 24
    assert_bool(pm.can_prestige()).is_equal(false)
    pm.boards_solved_current_tier = 25
    assert_bool(pm.can_prestige()).is_equal(true)

func test_prestige_resets_economy_and_grants_stars():
    pm.lifetime_coins = 4000.0
    pm.boards_solved_current_tier = 25
    Economy.coins = 100.0
    pm.prestige()
    assert_int(Economy.coins).is_equal(0)
    assert_int(SkillTree.stars).is_equal(2)
    assert_int(pm.prestige_count).is_equal(1)

func test_prestige_increases_permanent_multiplier():
    pm.lifetime_coins = 4000.0  # 2 stars
    pm.boards_solved_current_tier = 25
    var before := Economy.permanent_multiplier
    pm.prestige()
    assert_float(Economy.permanent_multiplier).is_equal_approx(before + 0.02, 0.001)
```

- [ ] **Step 2: Run test, expect FAIL**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_prestige.gd
```

Expected: FAIL.

- [ ] **Step 3: Implement PrestigeManager**

Create `/var/mnt/Linux_NVME/game/systems/prestige_manager.gd`:

```gdscript
extends Node

signal prestiged(stars_gained: int)

const BOARDS_PER_PRESTIGE: int = 25

var lifetime_coins: float = 0.0
var boards_solved_current_tier: int = 0
var prestige_count: int = 0

func reset() -> void:
    lifetime_coins = 0.0
    boards_solved_current_tier = 0
    prestige_count = 0

func record_coins(amount: float) -> void:
    lifetime_coins += amount

func record_board_solved() -> void:
    boards_solved_current_tier += 1

func calculate_stars() -> int:
    return int(floor(sqrt(lifetime_coins / 1000.0)))

func can_prestige() -> bool:
    return boards_solved_current_tier >= BOARDS_PER_PRESTIGE

func prestige() -> int:
    if not can_prestige():
        return 0
    var gained: int = calculate_stars()
    SkillTree.add_stars(gained)
    Economy.permanent_multiplier += gained * 0.01
    Economy.reset()
    prestige_count += 1
    boards_solved_current_tier = 0
    prestiged.emit(gained)
    return gained

func serialize() -> Dictionary:
    return {
        "lifetime_coins": lifetime_coins,
        "boards_solved_current_tier": boards_solved_current_tier,
        "prestige_count": prestige_count,
    }

func deserialize(data: Dictionary) -> void:
    lifetime_coins = data.get("lifetime_coins", 0.0)
    boards_solved_current_tier = data.get("boards_solved_current_tier", 0)
    prestige_count = data.get("prestige_count", 0)
```

- [ ] **Step 4: Register autoload**

Update `project.godot` autoload section:

```ini
[autoload]
Economy="*res://systems/economy.gd"
SaveSystem="*res://systems/save_system.gd"
SkillTree="*res://systems/skill_tree.gd"
PrestigeManager="*res://systems/prestige_manager.gd"
```

- [ ] **Step 5: Track coins and boards in main.gd**

Modify `_on_cell_filled` in `/var/mnt/Linux_NVME/game/ui/main.gd` — record after each award:

Replace:
```gdscript
    if not is_correct:
        return
    Economy.award_cell()
```

With:
```gdscript
    if not is_correct:
        return
    var before := Economy.coins
    Economy.award_cell()
    PrestigeManager.record_coins(Economy.coins - before)
```

And in the board_complete branch:
```gdscript
    if validator.is_board_complete(board):
        var before2 := Economy.coins
        Economy.award_board_complete(0.0)
        PrestigeManager.record_coins(Economy.coins - before2)
        PrestigeManager.record_board_solved()
        _save_game()
        _start_new_board()
```

- [ ] **Step 6: Run tests, expect PASS**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/test_prestige.gd
```

Expected: all 5 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add systems/prestige_manager.gd test/test_prestige.gd project.godot ui/main.gd
git commit -m "feat: PrestigeManager with stars formula + permanent multiplier"
```

---

## Task 16: PrestigeTab UI

**Files:**
- Create: `scenes/tabs/PrestigeTab.tscn`
- Create: `ui/prestige_tab.gd`
- Modify: `scenes/ui/BottomTabs.tscn`

- [ ] **Step 1: Create PrestigeTab scene**

Create `/var/mnt/Linux_NVME/game/scenes/tabs/PrestigeTab.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/prestige_tab.gd" id="1"]

[node name="Prestige" type="VBoxContainer"]
script = ExtResource("1")

[node name="StatusLabel" type="Label" parent="."]
text = "Progress: 0/25 boards"

[node name="StarsLabel" type="Label" parent="."]
text = "Stars on prestige: 0"

[node name="PrestigeButton" type="Button" parent="."]
text = "Prestige"
disabled = true
```

- [ ] **Step 2: Implement prestige_tab.gd**

Create `/var/mnt/Linux_NVME/game/ui/prestige_tab.gd`:

```gdscript
extends VBoxContainer

@onready var status_label: Label = $StatusLabel
@onready var stars_label: Label = $StarsLabel
@onready var prestige_button: Button = $PrestigeButton

func _ready() -> void:
    prestige_button.pressed.connect(_on_prestige_pressed)
    Economy.coins_changed.connect(_refresh)
    PrestigeManager.prestiged.connect(_on_prestiged)
    _refresh(Economy.coins)

func _refresh(_ignored: float = 0.0) -> void:
    var done: int = PrestigeManager.boards_solved_current_tier
    var target: int = PrestigeManager.BOARDS_PER_PRESTIGE
    status_label.text = "Progress: %d/%d boards" % [done, target]
    stars_label.text = "Stars on prestige: %d" % PrestigeManager.calculate_stars()
    prestige_button.disabled = not PrestigeManager.can_prestige()

func _on_prestige_pressed() -> void:
    PrestigeManager.prestige()
    _refresh()

func _on_prestiged(_stars: int) -> void:
    _refresh()
```

- [ ] **Step 3: Add tab to BottomTabs**

Modify `/var/mnt/Linux_NVME/game/scenes/ui/BottomTabs.tscn` — add ext_resource and node:

```
[ext_resource type="PackedScene" path="res://scenes/tabs/PrestigeTab.tscn" id="3"]
```

And add node after `Shop`:

```
[node name="Prestige" parent="." instance=ExtResource("3")]
```

- [ ] **Step 4: Update main.gd refresh after board complete**

Add to `_on_cell_filled` board-complete branch:

```gdscript
        var prestige_tab = $BottomTabs.get_node_or_null("Prestige")
        if prestige_tab:
            prestige_tab._refresh()
```

- [ ] **Step 5: Commit**

```bash
git add scenes/tabs/PrestigeTab.tscn ui/prestige_tab.gd scenes/ui/BottomTabs.tscn ui/main.gd
git commit -m "feat: PrestigeTab with progress + prestige button"
```

---

## Task 17: SkillTreeTab UI

**Files:**
- Create: `scenes/tabs/SkillTreeTab.tscn`
- Create: `ui/skill_tree_tab.gd`
- Modify: `scenes/ui/BottomTabs.tscn`

- [ ] **Step 1: Create SkillTreeTab scene**

Create `/var/mnt/Linux_NVME/game/scenes/tabs/SkillTreeTab.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/skill_tree_tab.gd" id="1"]

[node name="SkillTree" type="VBoxContainer"]
script = ExtResource("1")

[node name="StarsLabel" type="Label" parent="."]
text = "Stars: 0"

[node name="NodesList" type="VBoxContainer" parent="."]
```

- [ ] **Step 2: Implement skill_tree_tab.gd**

Create `/var/mnt/Linux_NVME/game/ui/skill_tree_tab.gd`:

```gdscript
extends VBoxContainer

@onready var stars_label: Label = $StarsLabel
@onready var nodes_list: VBoxContainer = $NodesList

var _node_buttons: Dictionary = {}

func _ready() -> void:
    SkillTree.stars_changed.connect(_on_stars_changed)
    SkillTree.node_unlocked.connect(_on_node_unlocked)
    _build_nodes()
    _refresh()

func _build_nodes() -> void:
    for node_id in SkillTree.NODES.keys():
        var btn := Button.new()
        nodes_list.add_child(btn)
        btn.pressed.connect(_on_node_pressed.bind(node_id))
        _node_buttons[node_id] = btn

func _refresh() -> void:
    stars_label.text = "Stars: %d" % SkillTree.stars
    for node_id in SkillTree.NODES.keys():
        var btn: Button = _node_buttons[node_id]
        var node: Dictionary = SkillTree.NODES[node_id]
        if SkillTree.is_unlocked(node_id):
            btn.text = "%s — UNLOCKED" % node_id
            btn.disabled = true
        else:
            btn.text = "%s (%d ★)" % [node_id, node["cost"]]
            btn.disabled = not SkillTree.can_unlock(node_id)

func _on_node_pressed(node_id: String) -> void:
    SkillTree.unlock(node_id)
    _refresh()

func _on_stars_changed(_new_total: int) -> void:
    _refresh()

func _on_node_unlocked(_node_id: String) -> void:
    _refresh()
```

- [ ] **Step 3: Add tab to BottomTabs.tscn**

Modify `/var/mnt/Linux_NVME/game/scenes/ui/BottomTabs.tscn` — add ext_resource id 4:

```
[ext_resource type="PackedScene" path="res://scenes/tabs/SkillTreeTab.tscn" id="4"]
```

And add node between `Shop` and `Prestige`:

```
[node name="SkillTree" parent="." instance=ExtResource("4")]
```

- [ ] **Step 4: Commit**

```bash
git add scenes/tabs/SkillTreeTab.tscn ui/skill_tree_tab.gd scenes/ui/BottomTabs.tscn
git commit -m "feat: SkillTreeTab with unlock buttons + cost display"
```

---

## Task 18: Full Save Integration (SkillTree + PrestigeManager)

**Files:**
- Modify: `ui/main.gd`

- [ ] **Step 1: Extend _save_game and _load_game**

Replace `_save_game` and `_load_game` in `/var/mnt/Linux_NVME/game/ui/main.gd`:

```gdscript
func _save_game() -> void:
    SaveSystem.save_data({
        "economy": Economy.serialize(),
        "skill_tree": SkillTree.serialize(),
        "prestige": PrestigeManager.serialize(),
    })

func _load_game() -> void:
    var data := SaveSystem.load_data()
    if data.has("economy"):
        Economy.deserialize(data["economy"])
    if data.has("skill_tree"):
        SkillTree.deserialize(data["skill_tree"])
    if data.has("prestige"):
        PrestigeManager.deserialize(data["prestige"])
```

- [ ] **Step 2: Smoke test**

Run:
```bash
godot --path . --headless --quit-after 60
```

Expected: no errors. Save file should now include all three systems.

- [ ] **Step 3: Commit**

```bash
git add ui/main.gd
git commit -m "feat: persist SkillTree and PrestigeManager state"
```

---

## Task 19: Unlock Higher Tiers via Skill Tree

**Files:**
- Modify: `ui/main.gd`

- [ ] **Step 1: Compute current tier from SkillTree**

Add helper function to `/var/mnt/Linux_NVME/game/ui/main.gd`:

```gdscript
func _current_tier() -> String:
    if SkillTree.is_unlocked("tier_hard"):
        return "hard"
    if SkillTree.is_unlocked("tier_medium"):
        return "medium"
    return "easy"
```

Replace `_start_new_board`:

```gdscript
func _start_new_board() -> void:
    var board := generator.generate(_current_tier())
    sudoku_board.set_board(board)
    top_bar.reset_timer()
```

- [ ] **Step 2: Smoke test**

Run:
```bash
godot --path . --headless --quit-after 30
```

Expected: clean exit.

- [ ] **Step 3: Commit**

```bash
git add ui/main.gd
git commit -m "feat: difficulty tier from SkillTree unlocks"
```

---

## Task 20: Web Export Preset

**Files:**
- Create: `export_presets.cfg`

- [ ] **Step 1: Install Godot export templates**

In Godot Editor: `Editor → Manage Export Templates → Download and Install`. Or via CLI:

```bash
godot --headless --quit  # ensures version known
flatpak run org.godotengine.Godot --install-export-templates
```

If that flag is unavailable, download templates manually from `https://github.com/godotengine/godot/releases` matching your Godot version, extract to `~/.var/app/org.godotengine.Godot/data/godot/export_templates/<version>/`.

- [ ] **Step 2: Create export_presets.cfg**

Create `/var/mnt/Linux_NVME/game/export_presets.cfg`:

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/index.html"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
```

- [ ] **Step 3: Test the export locally**

Run:
```bash
mkdir -p build
godot --headless --path . --export-release "Web" build/index.html
ls build/
```

Expected: `build/index.html`, `build/index.js`, `build/index.wasm`, `build/index.pck` (or similar).

- [ ] **Step 4: Smoke test in a local server**

Run:
```bash
python3 -m http.server --directory build 8000
```

Then open `http://localhost:8000` in a browser. Verify the game loads and is playable.

Kill the server with Ctrl-C.

- [ ] **Step 5: Commit**

```bash
git add export_presets.cfg
git commit -m "build: web export preset"
```

---

## Task 21: GitHub Actions CI/CD

**Files:**
- Create: `.github/workflows/deploy.yml`

- [ ] **Step 1: Create the workflow**

Create `/var/mnt/Linux_NVME/game/.github/workflows/deploy.yml`:

```yaml
name: Test, Build, Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: barichello/godot-ci:4.3
    steps:
      - uses: actions/checkout@v4
      - name: Run GdUnit4 tests
        run: |
          godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/ -c

  build:
    needs: test
    runs-on: ubuntu-latest
    container:
      image: barichello/godot-ci:4.3
    steps:
      - uses: actions/checkout@v4
      - name: Prepare export templates
        run: |
          mkdir -p ~/.local/share/godot/export_templates/
          mv /root/.local/share/godot/export_templates/4.3.stable ~/.local/share/godot/export_templates/ || true
      - name: Web export
        run: |
          mkdir -p build
          godot --headless --path . --export-release "Web" build/index.html
      - uses: actions/upload-pages-artifact@v3
        with:
          path: build/

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 2: Push and enable Pages in GitHub**

After pushing, in the GitHub repo: `Settings → Pages → Source: GitHub Actions`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/deploy.yml
git commit -m "ci: GitHub Actions for test + web export + Pages deploy"
```

---

## Task 22: Final Smoke Test and README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create README**

Create `/var/mnt/Linux_NVME/game/README.md`:

```markdown
# Sudokrement

Active incremental Sudoku game. Solve Sudokus → earn coins → buy upgrades → unlock skill tree → prestige for permanent multipliers.

## Run locally

```bash
flatpak run org.godotengine.Godot --path .
```

## Build for web

```bash
godot --headless --path . --export-release "Web" build/index.html
python3 -m http.server --directory build 8000
```

## Run tests

```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/
```

## Design

See `docs/superpowers/specs/2026-05-13-sudokrement-design.md`.
```

- [ ] **Step 2: Run full test suite one final time**

Run:
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/
```

Expected: ALL test files PASS (test_board, test_board_generator, test_validator, test_economy, test_save_system, test_skill_tree, test_prestige).

- [ ] **Step 3: Run a manual playtest**

Run:
```bash
godot --path .
```

Verify:
- Sudoku appears, cells clickable
- Typing 1-9 or clicking NumberPad fills cells
- Correct cells award coins, TopBar updates
- Difficulty selector changes multiplier
- Shop button "Hint" disables when broke, reveals a cell when purchased
- After 25 boards, Prestige button enables
- Prestige resets coins but grants Stars
- Skill-Tree tab shows nodes, allows unlocks

- [ ] **Step 4: Commit final state**

```bash
git add README.md
git commit -m "docs: README with run/build/test instructions"
```

---

## Self-Review Notes

**Spec coverage verified:**
- Difficulty modes (Casual/Standard/Hardcore): Task 5 economy + Task 12 UI selector. **Gap:** Standard mode 3-lives logic and Hardcore deferred-validation logic not implemented in MVP. They are listed as design but not wired in Tasks 5/9 — `is_correct` always allows entry. **Action:** This is acceptable for MVP since multipliers still apply; lives/deferred validation can be added in a follow-up plan as polish.
- Combo system (row/column/block/board): Tasks 4 + 5 + 9.
- Shop with Hint: Task 13. Other shop items (Auto-Note, Multi, Speed, Solver-Tick) deferred to follow-up.
- Skill Tree (Solvers/Economy/Progression branches): Tasks 14 + 17.
- Prestige (25 boards threshold, sqrt formula, +1% per Star): Tasks 15 + 16.
- Save/Load (autosave, IndexedDB): Tasks 10 + 11 + 18.
- Web export + GitHub Pages: Tasks 20 + 21.
- Killer Sudoku and 16x16: explicitly Nice-to-have, not in MVP — correct.
- Idle solver bots: deferred, not in MVP.

**Type consistency check:**
- `Board`, `Cell`, `Validator`, `BoardGenerator` are used consistently throughout.
- Autoload names `Economy`, `SaveSystem`, `SkillTree`, `PrestigeManager` consistent.
- Signal names: `coins_changed`, `cell_filled`, `cell_selected`, `number_pressed`, `erase_pressed`, `hint_purchased`, `prestiged`, `node_unlocked`, `stars_changed` — used identically in emit + connect.
- `serialize`/`deserialize` pattern uniform across systems.

**Placeholders:** none found after scan.

**Decisions documented:**
- Backtracking generator without uniqueness check — acceptable for MVP, noted.
- Hint item shown as MVP shop; other items as follow-up.
- Lives/Hardcore validation logic listed but deferred.
