# Streak-Multiplier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aufeinanderfolgende Combos innerhalb 15s erhöhen `Economy.run_multiplier` linear (+0.2 pro Streak, Cap ×3.0 bei count=10). Bricht bei falscher Eingabe, Zeitablauf oder Prestige.

**Architecture:** Neues Autoload `StreakManager` (analog `AchievementManager`) hört `GameEvents.combo_triggered`/`cell_filled`/`prestiged`, hält Counter+Timer, schreibt `Economy.run_multiplier` und emittiert `streak_changed`. UI-Indicator wird in `TopBar.tscn` eingebunden.

**Tech Stack:** Godot 4.6.2, GDScript, GdUnit4 (Flatpak `org.godotengine.Godot`).

**Spec:** `docs/superpowers/specs/2026-05-17-streak-multiplier-design.md`

---

## File Structure

**Neu:**
- `systems/streak_manager.gd` — Autoload, gesamte Streak-Logik
- `scenes/ui/StreakIndicator.tscn` + `ui/streak_indicator.gd` — UI-Komponente
- `test/test_streak_manager.gd` — Tests

**Geändert:**
- `systems/game_events.gd` — keine Änderung (Signal existiert bereits)
- `ui/sudoku_board.gd` (Zeile 147) — zusätzlich auf globalen Bus emittieren
- `ui/main.gd` (Zeilen 130-169) — Reihenfolge: `combo_triggered.emit` **vor** `award_combo`
- `scenes/ui/TopBar.tscn` — `StreakIndicator` einbinden
- `ui/top_bar.gd` — Node-Referenz und Bezug zu StreakManager-Signal (rein passiv, falls extra Hook nötig)
- `project.godot` — `StreakManager` als Autoload registrieren

---

### Task 1: StreakManager-Skelett mit failing Test

**Files:**
- Create: `systems/streak_manager.gd`
- Create: `test/test_streak_manager.gd`
- Modify: `project.godot` (autoload section)

- [ ] **Step 1: Skelett schreiben**

Erstelle `systems/streak_manager.gd`:

```gdscript
extends Node

signal streak_changed(count: int, multiplier: float, time_left: float, window: float)

const WINDOW_SEC: float = 15.0
const STEP: float = 0.2
const CAP_COUNT: int = 10
const CAP_MULT: float = 3.0

var count: int = 0
var multiplier: float = 1.0
var time_left: float = 0.0

func _ready() -> void:
	GameEvents.combo_triggered.connect(_on_combo)
	GameEvents.cell_filled.connect(_on_cell_filled)
	GameEvents.prestiged.connect(_on_prestiged)

func _process(delta: float) -> void:
	_tick(delta)

func _tick(delta: float) -> void:
	if count == 0:
		return
	time_left -= delta
	if time_left <= 0.0:
		_reset()

func _on_combo(_combo_type: String) -> void:
	count += 1
	time_left = WINDOW_SEC
	multiplier = min(1.0 + float(count) * STEP, CAP_MULT)
	Economy.run_multiplier = multiplier
	streak_changed.emit(count, multiplier, time_left, WINDOW_SEC)

func _on_cell_filled(correct: bool) -> void:
	if not correct:
		_reset()

func _on_prestiged(_stars_gained: int) -> void:
	_reset()

func reset() -> void:
	_reset()

func _reset() -> void:
	count = 0
	multiplier = 1.0
	time_left = 0.0
	Economy.run_multiplier = 1.0
	streak_changed.emit(count, multiplier, time_left, WINDOW_SEC)
```

- [ ] **Step 2: Autoload eintragen**

Modify `project.godot`, `[autoload]`-Section, neue Zeile nach `AchievementManager`:

```
StreakManager="*res://systems/streak_manager.gd"
```

(Reihenfolge muss nach `GameEvents` und `Economy` stehen — beide stehen weiter oben.)

- [ ] **Step 3: Test-Skelett mit erstem Test**

Erstelle `test/test_streak_manager.gd`:

```gdscript
extends GdUnitTestSuite

func before_test() -> void:
	StreakManager.reset()
	Economy.reset()

func test_combo_increments_count_and_multiplier() -> void:
	GameEvents.combo_triggered.emit("row")
	assert_int(StreakManager.count).is_equal(1)
	assert_float(StreakManager.multiplier).is_equal_approx(1.2, 0.001)
	GameEvents.combo_triggered.emit("column")
	GameEvents.combo_triggered.emit("block")
	assert_int(StreakManager.count).is_equal(3)
	assert_float(StreakManager.multiplier).is_equal_approx(1.6, 0.001)
```

(Beachte: `assert_float` mit `is_equal_approx`, nicht `assert_int` für float — siehe Memory `gdunit4_assert_int_vs_float`.)

- [ ] **Step 4: Test laufen lassen**

Run: `flatpak run org.godotengine.Godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a test/test_streak_manager.gd`

Expected: 1/1 grün.

- [ ] **Step 5: Commit**

```bash
git add systems/streak_manager.gd systems/streak_manager.gd.uid project.godot test/test_streak_manager.gd test/test_streak_manager.gd.uid
git commit -m "feat: StreakManager-Autoload mit Combo-Trigger + Counter"
```

(Falls `.uid`-Dateien noch nicht existieren, generiert Godot sie beim ersten Start — beim Commit ggf. erneut `git status` prüfen und nachreichen, vgl. Memory `roadmap_a_milestones_done`.)

---

### Task 2: Cap-Verhalten testen

**Files:**
- Test: `test/test_streak_manager.gd`

- [ ] **Step 1: Test schreiben**

Hänge an `test/test_streak_manager.gd` an:

```gdscript
func test_multiplier_caps_at_three() -> void:
	for i in range(15):
		GameEvents.combo_triggered.emit("row")
	assert_int(StreakManager.count).is_equal(15)
	assert_float(StreakManager.multiplier).is_equal_approx(3.0, 0.001)
```

- [ ] **Step 2: Lauf**

Run: `flatpak run org.godotengine.Godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a test/test_streak_manager.gd`

Expected: 2/2 grün. (Implementation in Task 1 hat `min(...)` schon.)

- [ ] **Step 3: Commit**

```bash
git add test/test_streak_manager.gd
git commit -m "test: StreakManager — Multiplier-Cap bei ×3.0"
```

---

### Task 3: Reset-Bedingungen testen

**Files:**
- Test: `test/test_streak_manager.gd`

- [ ] **Step 1: Tests schreiben**

Anhängen:

```gdscript
func test_wrong_cell_resets() -> void:
	GameEvents.combo_triggered.emit("row")
	GameEvents.combo_triggered.emit("row")
	assert_int(StreakManager.count).is_equal(2)
	GameEvents.cell_filled.emit(false)
	assert_int(StreakManager.count).is_equal(0)
	assert_float(StreakManager.multiplier).is_equal_approx(1.0, 0.001)

func test_correct_cell_does_not_reset() -> void:
	GameEvents.combo_triggered.emit("row")
	GameEvents.combo_triggered.emit("row")
	GameEvents.cell_filled.emit(true)
	assert_int(StreakManager.count).is_equal(2)

func test_time_expires_resets() -> void:
	GameEvents.combo_triggered.emit("row")
	StreakManager._tick(16.0)
	assert_int(StreakManager.count).is_equal(0)
	assert_float(StreakManager.multiplier).is_equal_approx(1.0, 0.001)

func test_combo_refreshes_window() -> void:
	GameEvents.combo_triggered.emit("row")
	StreakManager._tick(10.0)
	GameEvents.combo_triggered.emit("row")
	StreakManager._tick(10.0)
	assert_int(StreakManager.count).is_equal(2)

func test_prestige_resets() -> void:
	GameEvents.combo_triggered.emit("row")
	GameEvents.combo_triggered.emit("row")
	GameEvents.prestiged.emit(5)
	assert_int(StreakManager.count).is_equal(0)
	assert_float(StreakManager.multiplier).is_equal_approx(1.0, 0.001)

func test_tick_early_returns_when_count_zero() -> void:
	StreakManager._tick(100.0)
	assert_int(StreakManager.count).is_equal(0)
	assert_float(StreakManager.time_left).is_equal_approx(0.0, 0.001)
```

- [ ] **Step 2: Lauf**

Run: `flatpak run org.godotengine.Godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a test/test_streak_manager.gd`

Expected: 8/8 grün.

- [ ] **Step 3: Commit**

```bash
git add test/test_streak_manager.gd
git commit -m "test: StreakManager — Reset bei Fehler/Zeitablauf/Prestige"
```

---

### Task 4: Economy-Integration testen

**Files:**
- Test: `test/test_streak_manager.gd`

- [ ] **Step 1: Tests schreiben**

Anhängen:

```gdscript
func test_combo_updates_economy_run_multiplier() -> void:
	for i in range(5):
		GameEvents.combo_triggered.emit("row")
	assert_float(Economy.run_multiplier).is_equal_approx(2.0, 0.001)

func test_reset_restores_economy_run_multiplier() -> void:
	GameEvents.combo_triggered.emit("row")
	assert_float(Economy.run_multiplier).is_equal_approx(1.2, 0.001)
	GameEvents.cell_filled.emit(false)
	assert_float(Economy.run_multiplier).is_equal_approx(1.0, 0.001)
```

- [ ] **Step 2: Lauf**

Run: `flatpak run org.godotengine.Godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a test/test_streak_manager.gd`

Expected: 10/10 grün.

- [ ] **Step 3: Commit**

```bash
git add test/test_streak_manager.gd
git commit -m "test: StreakManager schreibt Economy.run_multiplier"
```

---

### Task 5: Signal-Emit testen

**Files:**
- Test: `test/test_streak_manager.gd`

- [ ] **Step 1: Test schreiben**

Anhängen (manueller Connect — siehe Memory `gdunit4_signal_assert`):

```gdscript
func test_streak_changed_signal_emits_payload() -> void:
	var received: Array = []
	var connector := func(c: int, m: float, t: float, w: float) -> void:
		received.append({"count": c, "mult": m, "time_left": t, "window": w})
	StreakManager.streak_changed.connect(connector)
	GameEvents.combo_triggered.emit("row")
	StreakManager.streak_changed.disconnect(connector)
	assert_int(received.size()).is_equal(1)
	assert_int(received[0]["count"]).is_equal(1)
	assert_float(received[0]["mult"]).is_equal_approx(1.2, 0.001)
	assert_float(received[0]["time_left"]).is_equal_approx(15.0, 0.001)
	assert_float(received[0]["window"]).is_equal_approx(15.0, 0.001)
```

- [ ] **Step 2: Lauf**

Run: `flatpak run org.godotengine.Godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a test/test_streak_manager.gd`

Expected: 11/11 grün.

- [ ] **Step 3: Commit**

```bash
git add test/test_streak_manager.gd
git commit -m "test: StreakManager emittiert streak_changed-Payload"
```

---

### Task 6: `cell_filled` auf globalen Bus emittieren

**Files:**
- Modify: `ui/sudoku_board.gd` (Zeile ~147)

Hintergrund: `GameEvents.cell_filled` ist in `systems/game_events.gd` deklariert (`signal cell_filled(correct: bool)`), wird aber bislang nicht emittiert — das Board feuert nur sein lokales Signal `cell_filled(row, col, value, correct)`. Streak-Bruch braucht den globalen Bus.

- [ ] **Step 1: Emit ergänzen**

In `ui/sudoku_board.gd`, in `input_value`, direkt **nach** der bestehenden Zeile `cell_filled.emit(selected_row, selected_col, value, correct)` (aktuell Zeile 147) folgende Zeile einfügen:

```gdscript
	GameEvents.cell_filled.emit(correct)
```

(Nur wenn `value > 0` — sonst zählt das Leeren einer Zelle als Fehler. Korrekte Variante:)

```gdscript
	if value > 0:
		GameEvents.cell_filled.emit(correct)
```

- [ ] **Step 2: Integration-Test schreiben**

Hänge an `test/test_streak_manager.gd` an:

```gdscript
func test_cell_filled_false_via_bus_resets() -> void:
	GameEvents.combo_triggered.emit("row")
	GameEvents.combo_triggered.emit("row")
	GameEvents.cell_filled.emit(false)
	assert_int(StreakManager.count).is_equal(0)
```

(Dieser Test deckt den Bus-Pfad ab — die Board-Integration ist UI-Code und im MVP nicht testbar; Spec sagt explizit "UI nicht im MVP-Scope".)

- [ ] **Step 3: Lauf**

Run: `flatpak run org.godotengine.Godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a test/test_streak_manager.gd`

Expected: 12/12 grün.

- [ ] **Step 4: Commit**

```bash
git add ui/sudoku_board.gd test/test_streak_manager.gd
git commit -m "feat: Sudoku-Board emittiert cell_filled auf globalen Bus"
```

---

### Task 7: Combo-Award-Reihenfolge in `ui/main.gd` umdrehen

**Files:**
- Modify: `ui/main.gd` (Zeilen ~130-169, drei Combo-Branches)

Hintergrund: Aktuell ruft `main.gd` `Economy.award_combo(...)` **vor** `GameEvents.combo_triggered.emit(...)`. Damit Award den neuen `run_multiplier` sieht, muss die Reihenfolge umgedreht werden.

- [ ] **Step 1: Row-Branch umstellen**

In `ui/main.gd`, Row-Branch (aktuell Zeilen 130-141):

```gdscript
		if validator.is_row_complete(board, row) and not board.rows_awarded.get(row, false):
			board.rows_awarded[row] = true
			board.combos_this_run += 1
			GameEvents.combo_triggered.emit("row")
			var b: float = Economy.coins
			Economy.award_combo("row")
			PrestigeManager.record_coins(Economy.coins - b)
			var cells: Array = []
			for c in range(board.size):
				cells.append(Vector2i(row, c))
			sudoku_board.combo_wave(cells, Color(0, 0.94, 1, 1))
			combo_triggered = true
```

- [ ] **Step 2: Column-Branch umstellen**

Analog (aktuell Zeilen 142-153):

```gdscript
		if validator.is_column_complete(board, col) and not board.cols_awarded.get(col, false):
			board.cols_awarded[col] = true
			board.combos_this_run += 1
			GameEvents.combo_triggered.emit("column")
			var b: float = Economy.coins
			Economy.award_combo("column")
			PrestigeManager.record_coins(Economy.coins - b)
			var cells: Array = []
			for r in range(board.size):
				cells.append(Vector2i(r, col))
			sudoku_board.combo_wave(cells, Color(0, 0.94, 1, 1))
			combo_triggered = true
```

- [ ] **Step 3: Block-Branch umstellen**

Analog (aktuell Zeilen 154-169):

```gdscript
		var block_key: int = (row / 3) * 3 + (col / 3)
		if validator.is_block_complete(board, row, col) and not board.blocks_awarded.get(block_key, false):
			board.blocks_awarded[block_key] = true
			board.combos_this_run += 1
			GameEvents.combo_triggered.emit("block")
			var b: float = Economy.coins
			Economy.award_combo("block")
			PrestigeManager.record_coins(Economy.coins - b)
			var cells: Array = []
			var br: int = (row / 3) * 3
			var bc: int = (col / 3) * 3
			for r in range(br, br + 3):
				for c in range(bc, bc + 3):
					cells.append(Vector2i(r, c))
			sudoku_board.combo_wave(cells, Color(1, 0, 0.67, 1))
			combo_triggered = true
```

- [ ] **Step 4: Integration-Test schreiben**

Hänge an `test/test_streak_manager.gd` an — verifiziert, dass die Reihenfolge "erst combo_triggered, dann award_combo" den höheren Multiplier ergibt:

```gdscript
func test_award_combo_uses_new_multiplier_after_streak_update() -> void:
	# Vor dem ersten Combo: run_multiplier = 1.0
	# Nach 1× combo_triggered: run_multiplier = 1.2
	# award_combo("row") soll bei 1.2 verrechnen, nicht bei 1.0.
	Economy.coins = 0.0
	GameEvents.combo_triggered.emit("row")
	Economy.award_combo("row")
	# row-Bonus = 10.0 × difficulty(casual=1.0) × perm(1.0) × run(1.2) = 12.0
	assert_float(Economy.coins).is_equal_approx(12.0, 0.01)
```

- [ ] **Step 5: Lauf — alle Tests**

Run: `flatpak run org.godotengine.Godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a test/`

Expected: alle Tests grün (74 vorher + 13 neue = 87).

(Falls Economy-Tests `Economy.run_multiplier` voraussetzen = 1.0 nach `reset()`: Economy.reset() setzt ihn bereits. Falls trotzdem Failures: prüfen, ob Tests den StreakManager triggern könnten.)

- [ ] **Step 6: Commit**

```bash
git add ui/main.gd test/test_streak_manager.gd
git commit -m "fix(ui): combo_triggered vor award_combo emittieren, damit Streak greift"
```

---

### Task 8: StreakIndicator-UI-Skript

**Files:**
- Create: `ui/streak_indicator.gd`

- [ ] **Step 1: Skript schreiben**

Erstelle `ui/streak_indicator.gd`:

```gdscript
extends HBoxContainer

const STREAK_COLOR: Color = Color(1, 0.84, 0.2, 1)

@onready var label: Label = $StreakLabel
@onready var bar: ProgressBar = $TimerBar

func _ready() -> void:
	label.add_theme_color_override("font_color", STREAK_COLOR)
	label.add_theme_font_size_override("font_size", 18)
	StreakManager.streak_changed.connect(_on_streak_changed)
	_apply(StreakManager.count, StreakManager.multiplier, StreakManager.time_left, StreakManager.WINDOW_SEC)

func _process(_delta: float) -> void:
	# Bar nutzt time_left aus StreakManager — pollt jeden Frame, weil das Signal
	# nur bei Streak-Events feuert, nicht pro Tick.
	if StreakManager.count > 0:
		bar.value = StreakManager.time_left

func _on_streak_changed(count: int, multiplier: float, time_left: float, window: float) -> void:
	_apply(count, multiplier, time_left, window)

func _apply(count: int, multiplier: float, time_left: float, window: float) -> void:
	visible = count > 0
	if count == 0:
		return
	label.text = "Streak %d ×%.1f" % [count, multiplier]
	bar.max_value = window
	bar.value = time_left
```

- [ ] **Step 2: Commit (ohne Test, UI ist außerhalb des Test-Scopes)**

```bash
git add ui/streak_indicator.gd
git commit -m "feat(ui): StreakIndicator-Skript (Label + Timer-Bar)"
```

---

### Task 9: StreakIndicator-Scene und Integration in TopBar

**Files:**
- Create: `scenes/ui/StreakIndicator.tscn`
- Modify: `scenes/ui/TopBar.tscn`

- [ ] **Step 1: Scene im Godot-Editor erstellen**

Öffne Godot: `flatpak run org.godotengine.Godot --path .`

1. Neue Scene → Root `HBoxContainer`, Name `StreakIndicator`.
2. Skript `res://ui/streak_indicator.gd` zuweisen.
3. Child `Label`, Name `StreakLabel`. Text initial: leer.
4. Child `ProgressBar`, Name `TimerBar`. Properties: `min_value = 0`, `max_value = 15`, `show_percentage = false`, `custom_minimum_size.x = 60`, `custom_minimum_size.y = 6`.
5. Speichern als `res://scenes/ui/StreakIndicator.tscn`.

(Wenn Editor nicht verfügbar: Scene-Datei manuell schreiben. Beispiel-Inhalt für `scenes/ui/StreakIndicator.tscn`:)

```
[gd_scene load_steps=2 format=3 uid="uid://placeholder"]

[ext_resource type="Script" path="res://ui/streak_indicator.gd" id="1"]

[node name="StreakIndicator" type="HBoxContainer"]
script = ExtResource("1")
visible = false

[node name="StreakLabel" type="Label" parent="."]
text = ""

[node name="TimerBar" type="ProgressBar" parent="."]
custom_minimum_size = Vector2(60, 6)
min_value = 0.0
max_value = 15.0
show_percentage = false
```

(uid wird beim ersten Editor-Open gesetzt.)

- [ ] **Step 2: TopBar.tscn um StreakIndicator erweitern**

Öffne `scenes/ui/TopBar.tscn` im Editor:

1. Als Child der TopBar (HBoxContainer) — Position nach `CoinsLabel`, vor `TimerLabel` — `Instantiate Child Scene` → `StreakIndicator.tscn`.
2. Speichern.

(Manuelle Edit-Variante: in `TopBar.tscn` einen `[ext_resource]` für `StreakIndicator.tscn` hinzufügen und einen Node-Eintrag mit `parent="."` ergänzen.)

- [ ] **Step 3: Smoke-Test in Godot-GUI**

Run: `flatpak run org.godotengine.Godot --path .`

Start "Main"-Scene, löse Row → StreakIndicator wird sichtbar, zeigt `Streak 1 ×1.2`, Timer-Bar schrumpft über 15s, verschwindet bei Reset.

(Erwartetes Verhalten visuell prüfen — kein automatischer Test.)

- [ ] **Step 4: Commit**

```bash
git add scenes/ui/StreakIndicator.tscn scenes/ui/TopBar.tscn
git commit -m "feat(ui): StreakIndicator in TopBar einbinden"
```

---

### Task 10: Full-Suite-Lauf + Memory-Update

**Files:**
- Modify: `/home/alex/.claude/projects/-var-mnt-Linux-NVME-game/memory/MEMORY.md`
- Create: `/home/alex/.claude/projects/-var-mnt-Linux-NVME-game/memory/roadmap_c_streak_done.md`

- [ ] **Step 1: Alle Tests laufen lassen**

Run: `flatpak run org.godotengine.Godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a test/`

Expected: 87/87 grün (74 vorher + 13 neue).

(Falls Test-Isolation-Issue: vor jedem Test, der combo_triggered feuert, in `before_test()` neben `StreakManager.reset()` auch andere Subscriber prüfen — Memory `test_isolation_autoload_side_effects`.)

- [ ] **Step 2: CI-Run nach Push**

```bash
git push
gh run list --limit 1
gh run watch
```

Expected: grün, Pages-Deploy aktualisiert.

- [ ] **Step 3: Memory-Datei schreiben**

Erstelle `/home/alex/.claude/projects/-var-mnt-Linux-NVME-game/memory/roadmap_c_streak_done.md`:

```markdown
---
name: roadmap-c-streak-done
description: Roadmap-Punkt C (Streak-Multiplier) live auf main — Combo-Streak mit 15s-Fenster, +0.2/Streak, Cap ×3.0.
metadata:
  node_type: memory
  type: project
---

Roadmap-Punkt C der Idle-Mechanics-Roadmap ist auf main implementiert.

**Status (Stand 2026-05-17):**
- 10 Implementation-Tasks erledigt (Spec→Plan→TDD→Deploy)
- 87/87 Tests grün (vorher 74/74 — 13 neue StreakManager-Tests)
- Live: https://kenblasse.github.io/Sudokrement/

**Was geliefert wurde:**
- `systems/streak_manager.gd` — Autoload, count/multiplier/time_left,
  Window 15s, STEP 0.2, CAP_MULT 3.0 bei CAP_COUNT 10
- `ui/streak_indicator.gd` + `scenes/ui/StreakIndicator.tscn` — Label + ProgressBar in TopBar
- `ui/sudoku_board.gd` emittiert `GameEvents.cell_filled` auf globalen Bus
- `ui/main.gd` Combo-Branches: `combo_triggered.emit` vor `award_combo` (Reihenfolge-Fix)

**Verwandt:**
- Roadmap: `docs/superpowers/specs/2026-05-15-idle-mechanics-roadmap.md`
- Spec: `docs/superpowers/specs/2026-05-17-streak-multiplier-design.md`
- Plan: `docs/superpowers/plans/2026-05-17-streak-multiplier.md`

**Nächster Roadmap-Punkt:** G (Hint-Currency — passive Regeneration, Coin-Kauf, Skill-Tree-Cap).
```

- [ ] **Step 4: MEMORY.md ergänzen**

In `/home/alex/.claude/projects/-var-mnt-Linux-NVME-game/memory/MEMORY.md` eine Zeile anhängen:

```markdown
- [Roadmap-C Streak-Multiplier erledigt](roadmap_c_streak_done.md) — 2026-05-17 live: Combo-Streak mit 15s-Fenster, +0.2/Streak, Cap ×3.0, 87/87 Tests grün.
```

- [ ] **Step 5: Commit Memory ist nicht im Repo — keine Commit-Action für Memory.**

Repo-State: clean nach Task 9. Keine weiteren Commits.

---

## Verwandt

- Spec: `docs/superpowers/specs/2026-05-17-streak-multiplier-design.md`
- Roadmap: `docs/superpowers/specs/2026-05-15-idle-mechanics-roadmap.md`
- Vorgänger-Plan: `docs/superpowers/plans/2026-05-16-soft-caps.md`
