# Milestones / Achievements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zweite Star-Quelle via Achievements bauen: 10 Achievements in drei Trigger-Typen (counter/event/condition), Toast-Layer + Achievements-Tab, voll headless-testbar.

**Architecture:** Neuer Autoload `GameEvents` als reiner Signal-Bus. Neuer Autoload `AchievementManager` mit statischem Const-Dictionary-Katalog, hört auf den Bus, vergibt Stars über das bestehende `SkillTree`. UI bekommt Toast (Tween, in `Main.tscn` eingebettet) und vierten Tab in `BottomTabs`. Persistenz additiv im bestehenden Save-Schema.

**Tech Stack:** Godot 4.6.2, GDScript, GdUnit4 für Tests, Flatpak-Runner für Headless-Builds. Spec: `docs/superpowers/specs/2026-05-15-milestones-design.md`.

---

## File Structure

**Create:**
- `systems/game_events.gd` — Signal-Bus, Autoload, nur Signal-Definitionen.
- `systems/achievement_manager.gd` — Autoload, Katalog + Auswertung + Save.
- `scenes/tabs/AchievementsTab.tscn` — Tab-Scene.
- `ui/achievements_tab.gd` — Tab-Logik.
- `scenes/ui/AchievementToast.tscn` — Toast-Scene.
- `ui/achievement_toast.gd` — Toast-Logik + Queue.
- `assets/icons/lock.svg` — Lock-Icon für gesperrte Achievements.
- `test/test_achievement_manager.gd` — Unit-Tests.
- `test/test_game_events.gd` — Signal-Bus-Smoketests.

**Modify:**
- `project.godot` — zwei neue Autoloads.
- `systems/board.gd` — `mistakes_this_run`, `combos_this_run` Felder.
- `systems/prestige_manager.gd` — `lifetime_coins_changed`-Signal, `GameEvents.prestiged.emit(...)`.
- `systems/skill_tree.gd` — `GameEvents.skill_unlocked.emit(...)`.
- `systems/sound_manager.gd` — neue `achievement()`-Methode.
- `ui/main.gd` — `GameEvents`-Emits, Board-Tracking-Felder, Save-Hook.
- `scenes/ui/BottomTabs.tscn` — vierter Tab.
- `scenes/Main.tscn` — Toast-Layer.

---

## Task 1: GameEvents-Autoload anlegen

**Files:**
- Create: `systems/game_events.gd`
- Test: `test/test_game_events.gd`
- Modify: `project.godot`

- [ ] **Step 1: Failing test schreiben**

`test/test_game_events.gd`:

```gdscript
extends GdUnitTestSuite

func test_board_solved_signal_carries_dictionary() -> void:
    var received: Array = []
    var connector := func(payload: Dictionary) -> void:
        received.append(payload)
    GameEvents.board_solved.connect(connector)
    GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 30.0, "mistakes": 0, "combos_in_board": 2})
    GameEvents.board_solved.disconnect(connector)
    assert_int(received.size()).is_equal(1)
    assert_str(received[0]["difficulty"]).is_equal("casual")
    assert_int(received[0]["mistakes"]).is_equal(0)

func test_combo_triggered_signal_carries_type() -> void:
    var received: Array = []
    var connector := func(t: String) -> void: received.append(t)
    GameEvents.combo_triggered.connect(connector)
    GameEvents.combo_triggered.emit("row")
    GameEvents.combo_triggered.disconnect(connector)
    assert_int(received.size()).is_equal(1)
    assert_str(received[0]).is_equal("row")

func test_prestiged_signal_carries_int() -> void:
    var received: Array = []
    var connector := func(n: int) -> void: received.append(n)
    GameEvents.prestiged.connect(connector)
    GameEvents.prestiged.emit(5)
    GameEvents.prestiged.disconnect(connector)
    assert_int(received[0]).is_equal(5)

func test_skill_unlocked_signal_carries_id() -> void:
    var received: Array = []
    var connector := func(id: String) -> void: received.append(id)
    GameEvents.skill_unlocked.connect(connector)
    GameEvents.skill_unlocked.emit("naked_single")
    GameEvents.skill_unlocked.disconnect(connector)
    assert_str(received[0]).is_equal("naked_single")
```

- [ ] **Step 2: Test laufen lassen, soll failen**

Run: `flatpak run org.godotengine.Godot --headless --add res://test/test_game_events.gd -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd`

Erwartung: FAIL mit "GameEvents not defined" oder "autoload missing".

(Hinweis: Falls das GdUnit4-CLI im Projekt anders aufgerufen wird, ist das exakte Kommando in `addons/gdUnit4/runtest.sh` zu finden. Befehl entsprechend anpassen.)

- [ ] **Step 3: `systems/game_events.gd` anlegen**

```gdscript
extends Node

signal board_solved(payload: Dictionary)
signal combo_triggered(combo_type: String)
signal cell_filled(correct: bool)
signal prestiged(stars_gained: int)
signal skill_unlocked(node_id: String)
```

- [ ] **Step 4: Autoload in `project.godot` registrieren**

`project.godot` Block `[autoload]` — `GameEvents` ALS ERSTER Eintrag, damit andere Autoloads beim Init darauf zugreifen können:

```ini
[autoload]

GameEvents="*res://systems/game_events.gd"
Economy="*res://systems/economy.gd"
SaveSystem="*res://systems/save_system.gd"
SkillTree="*res://systems/skill_tree.gd"
PrestigeManager="*res://systems/prestige_manager.gd"
SoundManager="*res://systems/sound_manager.gd"
```

- [ ] **Step 5: Test laufen lassen, soll passen**

Run wie Step 2. Erwartung: 4 Tests pass.

- [ ] **Step 6: Commit**

```bash
git add systems/game_events.gd project.godot test/test_game_events.gd
git commit -m "feat: GameEvents-Autoload als zentraler Signal-Bus"
```

---

## Task 2: PrestigeManager-Signal `lifetime_coins_changed`

**Files:**
- Modify: `systems/prestige_manager.gd`

- [ ] **Step 1: Failing test in `test/test_prestige_manager.gd` ergänzen oder neu anlegen**

Wenn die Datei nicht existiert, neu anlegen mit:

```gdscript
extends GdUnitTestSuite

func test_record_coins_emits_lifetime_changed() -> void:
    var pm := load("res://systems/prestige_manager.gd").new()
    var received: Array = []
    var connector := func(n: float) -> void: received.append(n)
    pm.lifetime_coins_changed.connect(connector)
    pm.record_coins(42.0)
    pm.record_coins(8.0)
    assert_int(received.size()).is_equal(2)
    assert_float(received[0]).is_equal_approx(42.0, 0.001)
    assert_float(received[1]).is_equal_approx(50.0, 0.001)
```

Wenn Datei existiert: Test-Funktion anhängen.

- [ ] **Step 2: Test laufen lassen, soll failen**

Run: `flatpak run org.godotengine.Godot --headless --add res://test/test_prestige_manager.gd -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd`

Erwartung: FAIL mit "signal not defined".

- [ ] **Step 3: Signal in `systems/prestige_manager.gd` ergänzen**

Nach Zeile 3 (`signal prestiged(stars_gained: int)`):

```gdscript
signal lifetime_coins_changed(new_total: float)
```

In `record_coins(amount: float)` ergänzen:

```gdscript
func record_coins(amount: float) -> void:
    lifetime_coins += amount
    lifetime_coins_changed.emit(lifetime_coins)
```

- [ ] **Step 4: Test laufen lassen, soll passen**

Erwartung: PASS.

- [ ] **Step 5: Commit**

```bash
git add systems/prestige_manager.gd test/test_prestige_manager.gd
git commit -m "feat: lifetime_coins_changed-Signal in PrestigeManager"
```

---

## Task 3: `GameEvents`-Emits in PrestigeManager und SkillTree

**Files:**
- Modify: `systems/prestige_manager.gd`, `systems/skill_tree.gd`
- Test: `test/test_prestige_manager.gd`, `test/test_skill_tree.gd` (falls nicht vorhanden, neu)

- [ ] **Step 1: Failing tests schreiben**

In `test/test_prestige_manager.gd` anhängen:

```gdscript
func test_prestige_emits_on_bus() -> void:
    Economy.reset()
    PrestigeManager.reset()
    PrestigeManager.boards_solved_current_tier = PrestigeManager.BOARDS_PER_PRESTIGE
    PrestigeManager.lifetime_coins = 1_000_000.0
    var received: Array = []
    var connector := func(n: int) -> void: received.append(n)
    GameEvents.prestiged.connect(connector)
    PrestigeManager.prestige()
    GameEvents.prestiged.disconnect(connector)
    assert_int(received.size()).is_equal(1)
    assert_int(received[0]).is_greater(0)
```

In `test/test_skill_tree.gd` (neu falls nicht da):

```gdscript
extends GdUnitTestSuite

func test_unlock_emits_on_bus() -> void:
    SkillTree.reset()
    SkillTree.add_stars(10)
    var received: Array = []
    var connector := func(id: String) -> void: received.append(id)
    GameEvents.skill_unlocked.connect(connector)
    SkillTree.unlock("naked_single")
    GameEvents.skill_unlocked.disconnect(connector)
    assert_int(received.size()).is_equal(1)
    assert_str(received[0]).is_equal("naked_single")
```

- [ ] **Step 2: Tests laufen lassen, sollen failen**

Erwartung: FAIL — `received[0]` nicht vorhanden / size == 0.

- [ ] **Step 3: `systems/prestige_manager.gd` — Emit hinzufügen**

In `prestige()`, NACH `prestiged.emit(gained)` und VOR `return gained`:

```gdscript
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
    GameEvents.prestiged.emit(gained)
    return gained
```

- [ ] **Step 4: `systems/skill_tree.gd` — Emit hinzufügen**

In `unlock()`, nach `node_unlocked.emit(node_id)`:

```gdscript
func unlock(node_id: String) -> bool:
    if not can_unlock(node_id):
        return false
    var node: Dictionary = NODES[node_id]
    stars -= node["cost"]
    unlocked[node_id] = true
    node_unlocked.emit(node_id)
    stars_changed.emit(stars)
    GameEvents.skill_unlocked.emit(node_id)
    return true
```

- [ ] **Step 5: Tests laufen lassen, sollen passen**

Erwartung: PASS.

- [ ] **Step 6: Commit**

```bash
git add systems/prestige_manager.gd systems/skill_tree.gd test/
git commit -m "feat: PrestigeManager/SkillTree emittieren auf GameEvents-Bus"
```

---

## Task 4: Board-Felder für Mistake- und Combo-Tracking

**Files:**
- Modify: `systems/board.gd`
- Test: `test/test_board.gd` (falls nicht vorhanden, neu)

- [ ] **Step 1: Failing test schreiben**

`test/test_board.gd` (neu falls nicht da):

```gdscript
extends GdUnitTestSuite

func test_board_tracks_mistakes_and_combos_default_zero() -> void:
    var board: Board = Board.new(9)
    assert_int(board.mistakes_this_run).is_equal(0)
    assert_int(board.combos_this_run).is_equal(0)
```

- [ ] **Step 2: Test laufen lassen, soll failen**

Erwartung: FAIL — Felder nicht definiert.

- [ ] **Step 3: Felder in `systems/board.gd` ergänzen**

Nach `var blocks_awarded: Dictionary = {}` (Zeile 12):

```gdscript
var mistakes_this_run: int = 0
var combos_this_run: int = 0
```

- [ ] **Step 4: Test laufen lassen, soll passen**

Erwartung: PASS.

- [ ] **Step 5: Commit**

```bash
git add systems/board.gd test/test_board.gd
git commit -m "feat: Board trackt mistakes_this_run und combos_this_run"
```

---

## Task 5: AchievementManager — Katalog + Counter-Logik (TDD)

**Files:**
- Create: `systems/achievement_manager.gd`, `test/test_achievement_manager.gd`
- Modify: `project.godot`

- [ ] **Step 1: Failing test "counter erreicht Threshold" schreiben**

`test/test_achievement_manager.gd`:

```gdscript
extends GdUnitTestSuite

func before_test() -> void:
    AchievementManager.reset()
    SkillTree.reset()

func test_counter_unlocks_at_threshold() -> void:
    var received: Array = []
    var connector := func(id: String, stars: int) -> void:
        received.append({"id": id, "stars": stars})
    AchievementManager.achievement_unlocked.connect(connector)
    for i in range(10):
        GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 120.0, "mistakes": 5, "combos_in_board": 0})
    AchievementManager.achievement_unlocked.disconnect(connector)
    var ids: Array = []
    for r in received: ids.append(r["id"])
    assert_bool(ids.has("solve_10_boards")).is_true()
    assert_bool(AchievementManager.unlocked.get("solve_10_boards", false)).is_true()

func test_counter_does_not_unlock_below_threshold() -> void:
    for i in range(9):
        GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 120.0, "mistakes": 5, "combos_in_board": 0})
    assert_bool(AchievementManager.unlocked.get("solve_10_boards", false)).is_false()

func test_counter_does_not_unlock_twice() -> void:
    var received_count: int = 0
    var connector := func(id: String, _stars: int) -> void:
        if id == "solve_10_boards":
            received_count += 1
    AchievementManager.achievement_unlocked.connect(connector)
    for i in range(15):
        GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 120.0, "mistakes": 5, "combos_in_board": 0})
    AchievementManager.achievement_unlocked.disconnect(connector)
    assert_int(received_count).is_equal(1)

func test_add_stars_called_on_unlock() -> void:
    var stars_before: int = SkillTree.stars
    for i in range(10):
        GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 120.0, "mistakes": 5, "combos_in_board": 0})
    assert_int(SkillTree.stars).is_equal(stars_before + 1)
```

- [ ] **Step 2: Tests laufen lassen, sollen failen**

Erwartung: FAIL — AchievementManager nicht definiert.

- [ ] **Step 3: `systems/achievement_manager.gd` anlegen (Minimal-Implementierung für counter+board_solved)**

```gdscript
extends Node

signal achievement_unlocked(id: String, stars: int)

const ACHIEVEMENTS: Dictionary = {
    "solve_10_boards":     {"type": "counter", "counter": "boards_solved",            "threshold": 10,     "stars": 1, "label": "Routine",         "desc": "10 Boards gelöst"},
    "solve_50_boards":     {"type": "counter", "counter": "boards_solved",            "threshold": 50,     "stars": 2, "label": "Veteran",         "desc": "50 Boards gelöst"},
    "combo_100_total":     {"type": "counter", "counter": "combos_total",             "threshold": 100,    "stars": 1, "label": "Comboliebhaber",  "desc": "100 Combos ausgelöst"},
    "earn_10k_lifetime":   {"type": "counter", "counter": "lifetime_coins_observed",  "threshold": 10000,  "stars": 1, "label": "Sparbuch",        "desc": "10.000 Coins lifetime verdient"},
    "first_hardcore":      {"type": "event", "event": "board_solved",     "check": "difficulty_hardcore", "stars": 2, "label": "Mutprobe",     "desc": "Erstes Hardcore-Board gelöst"},
    "first_prestige":      {"type": "event", "event": "prestiged",        "check": "",                    "stars": 2, "label": "Wiedergeburt", "desc": "Erstes Prestige"},
    "unlock_solvers_branch": {"type": "event", "event": "skill_unlocked", "check": "branch_solvers",      "stars": 1, "label": "Theoretiker",  "desc": "Ersten Solver-Skill freigeschaltet"},
    "perfect_board":         {"type": "condition", "event": "board_solved", "check": "no_mistakes",          "stars": 1, "label": "Makellos",       "desc": "Board ohne Fehler gelöst"},
    "speedrun_60s":          {"type": "condition", "event": "board_solved", "check": "under_60s",            "stars": 2, "label": "Blitzlöser",     "desc": "Board unter 60 Sek gelöst"},
    "five_combos_one_board": {"type": "condition", "event": "board_solved", "check": "five_combos_in_board", "stars": 1, "label": "Kettenreaktion", "desc": "5 Combos in einem Board"},
}

var counters: Dictionary = {
    "boards_solved": 0,
    "combos_total": 0,
    "lifetime_coins_observed": 0,
}
var unlocked: Dictionary = {}

func _ready() -> void:
    GameEvents.board_solved.connect(_on_board_solved)
    GameEvents.combo_triggered.connect(_on_combo_triggered)
    GameEvents.prestiged.connect(_on_prestiged)
    GameEvents.skill_unlocked.connect(_on_skill_unlocked)
    PrestigeManager.lifetime_coins_changed.connect(_on_lifetime_coins_changed)

func reset() -> void:
    counters = {"boards_solved": 0, "combos_total": 0, "lifetime_coins_observed": 0}
    unlocked = {}

func _on_board_solved(payload: Dictionary) -> void:
    counters["boards_solved"] = int(counters.get("boards_solved", 0)) + 1
    _evaluate_counter("boards_solved")
    _evaluate_event("board_solved", payload)
    _evaluate_condition("board_solved", payload)

func _on_combo_triggered(_combo_type: String) -> void:
    counters["combos_total"] = int(counters.get("combos_total", 0)) + 1
    _evaluate_counter("combos_total")

func _on_prestiged(_stars_gained: int) -> void:
    _evaluate_event("prestiged", {})

func _on_skill_unlocked(node_id: String) -> void:
    _evaluate_event("skill_unlocked", {"node_id": node_id})

func _on_lifetime_coins_changed(new_total: float) -> void:
    var lifetime: int = int(floor(new_total))
    if lifetime > int(counters.get("lifetime_coins_observed", 0)):
        counters["lifetime_coins_observed"] = lifetime
        _evaluate_counter("lifetime_coins_observed")

func _evaluate_counter(counter_key: String) -> void:
    var current: int = int(counters.get(counter_key, 0))
    for id in ACHIEVEMENTS:
        var a: Dictionary = ACHIEVEMENTS[id]
        if a["type"] != "counter": continue
        if a["counter"] != counter_key: continue
        if unlocked.get(id, false): continue
        if current >= int(a["threshold"]): _unlock(id)

func _evaluate_event(event_name: String, payload: Dictionary) -> void:
    for id in ACHIEVEMENTS:
        var a: Dictionary = ACHIEVEMENTS[id]
        if a["type"] != "event": continue
        if a.get("event", "") != event_name: continue
        if unlocked.get(id, false): continue
        if not _check_passes(a.get("check", ""), payload): continue
        _unlock(id)

func _evaluate_condition(event_name: String, payload: Dictionary) -> void:
    for id in ACHIEVEMENTS:
        var a: Dictionary = ACHIEVEMENTS[id]
        if a["type"] != "condition": continue
        if a.get("event", "") != event_name: continue
        if unlocked.get(id, false): continue
        if not _check_passes(a.get("check", ""), payload): continue
        _unlock(id)

func _check_passes(check: String, payload: Dictionary) -> bool:
    match check:
        "":
            return true
        "difficulty_hardcore":
            return payload.get("difficulty", "") == "hardcore"
        "branch_solvers":
            var node_id: String = payload.get("node_id", "")
            var node: Dictionary = SkillTree.NODES.get(node_id, {})
            return node.get("branch", "") == "solvers"
        "no_mistakes":
            return int(payload.get("mistakes", -1)) == 0
        "under_60s":
            return float(payload.get("time_seconds", INF)) < 60.0
        "five_combos_in_board":
            return int(payload.get("combos_in_board", 0)) >= 5
        _:
            push_warning("AchievementManager: unknown check '%s'" % check)
            return false

func _unlock(id: String) -> void:
    unlocked[id] = true
    var stars: int = int(ACHIEVEMENTS[id]["stars"])
    SkillTree.add_stars(stars)
    achievement_unlocked.emit(id, stars)

func serialize() -> Dictionary:
    return {
        "counters": counters.duplicate(),
        "unlocked": unlocked.duplicate(),
    }

func deserialize(data: Dictionary) -> void:
    counters = data.get("counters", {}).duplicate()
    unlocked = data.get("unlocked", {}).duplicate()
    for key in ["boards_solved", "combos_total", "lifetime_coins_observed"]:
        if not counters.has(key): counters[key] = 0
```

- [ ] **Step 4: Autoload registrieren**

`project.godot` Block `[autoload]`, ans Ende (nach SoundManager):

```ini
AchievementManager="*res://systems/achievement_manager.gd"
```

Komplette Reihenfolge danach: `GameEvents`, `Economy`, `SaveSystem`, `SkillTree`, `PrestigeManager`, `SoundManager`, `AchievementManager`.

- [ ] **Step 5: Tests laufen lassen, sollen passen**

Run: `flatpak run org.godotengine.Godot --headless --add res://test/test_achievement_manager.gd -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd`

Erwartung: 4 Tests pass.

- [ ] **Step 6: Commit**

```bash
git add systems/achievement_manager.gd project.godot test/test_achievement_manager.gd
git commit -m "feat: AchievementManager mit Counter-Logik"
```

---

## Task 6: AchievementManager — Event- und Condition-Logik testen

**Files:**
- Modify: `test/test_achievement_manager.gd`

- [ ] **Step 1: Tests für Event- und Condition-Typen anhängen**

```gdscript
func test_event_hardcore_only_on_hardcore() -> void:
    GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 30.0, "mistakes": 0, "combos_in_board": 0})
    assert_bool(AchievementManager.unlocked.get("first_hardcore", false)).is_false()
    GameEvents.board_solved.emit({"difficulty": "hardcore", "time_seconds": 30.0, "mistakes": 0, "combos_in_board": 0})
    assert_bool(AchievementManager.unlocked.get("first_hardcore", false)).is_true()

func test_event_first_prestige() -> void:
    GameEvents.prestiged.emit(3)
    assert_bool(AchievementManager.unlocked.get("first_prestige", false)).is_true()

func test_event_solvers_branch_skill() -> void:
    GameEvents.skill_unlocked.emit("naked_single")
    assert_bool(AchievementManager.unlocked.get("unlock_solvers_branch", false)).is_true()

func test_event_economy_branch_skill_does_not_unlock_solvers_ach() -> void:
    GameEvents.skill_unlocked.emit("coin_plus_10")
    assert_bool(AchievementManager.unlocked.get("unlock_solvers_branch", false)).is_false()

func test_condition_no_mistakes_required() -> void:
    GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 120.0, "mistakes": 2, "combos_in_board": 0})
    assert_bool(AchievementManager.unlocked.get("perfect_board", false)).is_false()
    GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 120.0, "mistakes": 0, "combos_in_board": 0})
    assert_bool(AchievementManager.unlocked.get("perfect_board", false)).is_true()

func test_condition_speedrun_60s() -> void:
    GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 75.0, "mistakes": 5, "combos_in_board": 0})
    assert_bool(AchievementManager.unlocked.get("speedrun_60s", false)).is_false()
    GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 45.0, "mistakes": 5, "combos_in_board": 0})
    assert_bool(AchievementManager.unlocked.get("speedrun_60s", false)).is_true()

func test_condition_five_combos_in_board() -> void:
    GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 120.0, "mistakes": 5, "combos_in_board": 5})
    assert_bool(AchievementManager.unlocked.get("five_combos_one_board", false)).is_true()

func test_lifetime_coins_observed_tracks() -> void:
    PrestigeManager.lifetime_coins = 0.0
    PrestigeManager.record_coins(9999.0)
    assert_bool(AchievementManager.unlocked.get("earn_10k_lifetime", false)).is_false()
    PrestigeManager.record_coins(2.0)
    assert_bool(AchievementManager.unlocked.get("earn_10k_lifetime", false)).is_true()

func test_unknown_check_does_not_crash() -> void:
    # Inject a synthetic achievement-style payload — we just hit the warning path.
    AchievementManager._check_passes("nonsense_check", {})
    assert_bool(true).is_true()
```

- [ ] **Step 2: Tests laufen lassen, sollen passen**

Erwartung: alle Tests aus Task 5 + diese neuen sind grün.

- [ ] **Step 3: Commit**

```bash
git add test/test_achievement_manager.gd
git commit -m "test: Event- und Condition-Achievements abgedeckt"
```

---

## Task 7: Save/Deserialize-Roundtrip

**Files:**
- Modify: `test/test_achievement_manager.gd`

- [ ] **Step 1: Roundtrip-Test schreiben**

```gdscript
func test_serialize_deserialize_roundtrip() -> void:
    AchievementManager.counters["boards_solved"] = 7
    AchievementManager.counters["combos_total"] = 42
    AchievementManager.unlocked["solve_10_boards"] = true
    var data: Dictionary = AchievementManager.serialize()
    AchievementManager.reset()
    assert_int(int(AchievementManager.counters["boards_solved"])).is_equal(0)
    AchievementManager.deserialize(data)
    assert_int(int(AchievementManager.counters["boards_solved"])).is_equal(7)
    assert_int(int(AchievementManager.counters["combos_total"])).is_equal(42)
    assert_bool(AchievementManager.unlocked.get("solve_10_boards", false)).is_true()

func test_deserialize_empty_dict_uses_defaults() -> void:
    AchievementManager.deserialize({})
    assert_int(int(AchievementManager.counters["boards_solved"])).is_equal(0)
    assert_int(int(AchievementManager.counters["combos_total"])).is_equal(0)
    assert_int(int(AchievementManager.counters["lifetime_coins_observed"])).is_equal(0)
    assert_int(AchievementManager.unlocked.size()).is_equal(0)
```

- [ ] **Step 2: Tests laufen lassen, sollen passen** (Implementierung steht bereits in Task 5)

- [ ] **Step 3: Commit**

```bash
git add test/test_achievement_manager.gd
git commit -m "test: Achievement-Save-Roundtrip"
```

---

## Task 8: Save-Hook in `ui/main.gd`

**Files:**
- Modify: `ui/main.gd`

- [ ] **Step 1: `_load_game()` und `_save_game()` erweitern**

`ui/main.gd:31-45` wird zu:

```gdscript
func _load_game() -> void:
    var data: Dictionary = SaveSystem.load_data()
    if data.has("economy"):
        Economy.deserialize(data["economy"])
    if data.has("skill_tree"):
        SkillTree.deserialize(data["skill_tree"])
    if data.has("prestige"):
        PrestigeManager.deserialize(data["prestige"])
    if data.has("achievements"):
        AchievementManager.deserialize(data["achievements"])

func _save_game() -> void:
    SaveSystem.save_data({
        "economy": Economy.serialize(),
        "skill_tree": SkillTree.serialize(),
        "prestige": PrestigeManager.serialize(),
        "achievements": AchievementManager.serialize(),
    })
```

- [ ] **Step 2: Manuell Save-Roundtrip prüfen**

Editor öffnen, ein paar Boards spielen, Achievement triggern, neu starten, prüfen ob `unlocked` erhalten bleibt.

Headless-Variante (falls Save-Pfad bekannt):

```bash
flatpak run org.godotengine.Godot --headless --quit 2>/dev/null
```

und in `~/.var/app/org.godotengine.Godot/data/godot/app_userdata/Sudokrement/save_slot0.json` prüfen, ob `achievements`-Block existiert.

- [ ] **Step 3: Commit**

```bash
git add ui/main.gd
git commit -m "feat: AchievementManager in Save-Aggregator einbinden"
```

---

## Task 9: `ui/main.gd` — GameEvents-Emits + Board-Tracking

**Files:**
- Modify: `ui/main.gd`

- [ ] **Step 1: Tracking-Variablen + `_start_new_board()` Reset**

In `_start_new_board()` (`ui/main.gd:73-82`) am Anfang nach `var board := generator.generate(...)`:

```gdscript
func _start_new_board() -> void:
    var board := generator.generate(_current_tier())
    sudoku_board.hide_wrong = Economy.difficulty_mode == "hardcore"
    sudoku_board.set_board(board)
    top_bar.reset_timer()
    board.start_time = Time.get_ticks_msec() / 1000.0
    _lives = STANDARD_LIVES
    _refresh_lives_label()
    var shop := side_tabs.get_node_or_null("Shop")
    if shop and shop.has_method("reset_board_session"):
        shop.reset_board_session()
```

Hinweis: `Board.start_time` existiert bereits laut `systems/board.gd:8`.

- [ ] **Step 2: `_on_cell_filled` — Mistakes und Combos tracken**

In `ui/main.gd:99-161`. An folgenden Stellen einfügen:

Nach `if value > 0 and not is_correct and Economy.difficulty_mode == "standard":` und vor `_lives -= 1`:

```gdscript
        var board2: Board = sudoku_board.board
        board2.mistakes_this_run += 1
```

In Hardcore-Pfad nach `validator.is_board_full(board)` `else`-Branch:

```gdscript
            SoundManager.wrong()
            board.mistakes_this_run += 1
            _start_new_board()
```

Bei jeder der drei `combo_triggered = true`-Stellen vorher:

```gdscript
        board.combos_this_run += 1
        GameEvents.combo_triggered.emit("row")  # bzw "column" / "block"
```

(Drei separate Stellen, jeweils mit passendem Combo-Typ.)

- [ ] **Step 3: `_award_board_complete` — `GameEvents.board_solved` emittieren**

`ui/main.gd:163-173` wird zu:

```gdscript
func _award_board_complete(board: Board) -> void:
    var before2: float = Economy.coins
    Economy.award_board_complete(0.0)
    PrestigeManager.record_coins(Economy.coins - before2)
    PrestigeManager.record_board_solved()
    SoundManager.board_complete()
    var elapsed: float = (Time.get_ticks_msec() / 1000.0) - board.start_time
    GameEvents.board_solved.emit({
        "difficulty": Economy.difficulty_mode,
        "time_seconds": elapsed,
        "mistakes": board.mistakes_this_run,
        "combos_in_board": board.combos_this_run,
    })
    var prestige_tab := side_tabs.get_node_or_null("Prestige")
    if prestige_tab:
        prestige_tab._refresh()
    _save_game()
    _start_new_board()
```

Beachte: Parameter ist jetzt `board: Board` (vorher `_board`). Aufrufer in `_on_cell_filled` rufen `_award_board_complete(board)` mit dem lokalen `board` auf — passt schon, prüfen.

- [ ] **Step 4: Manuell verifizieren**

Im Editor starten, ein Board casual lösen, Konsole prüfen — kein Crash, `_save_game` schreibt `achievements.counters.boards_solved == 1`.

- [ ] **Step 5: Commit**

```bash
git add ui/main.gd
git commit -m "feat: ui/main.gd emittiert GameEvents (board_solved, combo_triggered)"
```

---

## Task 10: Lock-Icon-Asset

**Files:**
- Create: `assets/icons/lock.svg`

- [ ] **Step 1: Lock-SVG schreiben**

Simples Schloss-SVG, Style-konform mit den bestehenden Icons in `assets/icons/`. Schau dir vorher `assets/icons/star.svg` und `assets/icons/heart.svg` als Stil-Referenz an (Größe, Strichstärke, Farbpalette).

`assets/icons/lock.svg`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <rect x="4" y="11" width="16" height="10" rx="2"/>
  <path d="M8 11V7a4 4 0 0 1 8 0v4"/>
</svg>
```

- [ ] **Step 2: Im Editor öffnen, Import-Settings prüfen**

Godot generiert automatisch `lock.svg.import`. Prüfen, dass die Datei als Texture2D erkannt wird.

- [ ] **Step 3: Commit**

```bash
git add assets/icons/lock.svg assets/icons/lock.svg.import
git commit -m "feat: lock.svg-Icon für gesperrte Achievements"
```

---

## Task 11: AchievementsTab — Scene + Script

**Files:**
- Create: `scenes/tabs/AchievementsTab.tscn`, `ui/achievements_tab.gd`

- [ ] **Step 1: `ui/achievements_tab.gd`**

```gdscript
extends VBoxContainer

const STAR_ICON: Texture2D = preload("res://assets/icons/star.svg")
const LOCK_ICON: Texture2D = preload("res://assets/icons/lock.svg")

@onready var header_label: Label = $Header
@onready var list_container: VBoxContainer = $Scroll/List

func _ready() -> void:
    AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
    _rebuild()

func _on_achievement_unlocked(_id: String, _stars: int) -> void:
    _rebuild()

func _rebuild() -> void:
    for child in list_container.get_children():
        child.queue_free()
    var unlocked_count: int = AchievementManager.unlocked.size()
    var total: int = AchievementManager.ACHIEVEMENTS.size()
    var earned_stars: int = 0
    for id in AchievementManager.unlocked:
        earned_stars += int(AchievementManager.ACHIEVEMENTS[id]["stars"])
    header_label.text = "Achievements (%d / %d)   ★ %d" % [unlocked_count, total, earned_stars]
    # Unlocked first (insertion order), then locked.
    var unlocked_ids: Array = AchievementManager.unlocked.keys()
    var locked_ids: Array = []
    for id in AchievementManager.ACHIEVEMENTS:
        if not AchievementManager.unlocked.has(id):
            locked_ids.append(id)
    for id in unlocked_ids: _add_row(id, true)
    for id in locked_ids: _add_row(id, false)

func _add_row(id: String, is_unlocked: bool) -> void:
    var data: Dictionary = AchievementManager.ACHIEVEMENTS[id]
    var row := HBoxContainer.new()
    row.modulate = Color(1, 1, 1, 1.0 if is_unlocked else 0.4)
    var icon := TextureRect.new()
    icon.texture = STAR_ICON if is_unlocked else LOCK_ICON
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.custom_minimum_size = Vector2(24, 24)
    row.add_child(icon)
    var text_box := VBoxContainer.new()
    text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var title := Label.new()
    title.text = data["label"]
    if is_unlocked: title.add_theme_color_override("font_color", Color(1, 1, 0.7))
    text_box.add_child(title)
    var desc := Label.new()
    desc.text = data["desc"]
    desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
    text_box.add_child(desc)
    row.add_child(text_box)
    var stars_label := Label.new()
    stars_label.text = "★ %d" % int(data["stars"])
    row.add_child(stars_label)
    list_container.add_child(row)
```

- [ ] **Step 2: `scenes/tabs/AchievementsTab.tscn`**

Im Editor neue Scene anlegen, Root = `VBoxContainer`, Script anhängen:
- `Header` (Label, child)
- `Scroll` (ScrollContainer, size_flags_vertical = SIZE_EXPAND_FILL, child)
  - `List` (VBoxContainer, child von Scroll)

`AchievementsTab.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/achievements_tab.gd" id="1"]

[node name="AchievementsTab" type="VBoxContainer"]
script = ExtResource("1")

[node name="Header" type="Label" parent="."]
text = "Achievements"

[node name="Scroll" type="ScrollContainer" parent="."]
size_flags_vertical = 3

[node name="List" type="VBoxContainer" parent="Scroll"]
size_flags_horizontal = 3
```

- [ ] **Step 3: Commit**

```bash
git add scenes/tabs/AchievementsTab.tscn ui/achievements_tab.gd
git commit -m "feat: AchievementsTab Scene + Script"
```

---

## Task 12: BottomTabs erweitern

**Files:**
- Modify: `scenes/ui/BottomTabs.tscn`

- [ ] **Step 1: Vierten Tab einfügen**

`scenes/ui/BottomTabs.tscn` wird zu:

```ini
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://ui/bottom_tabs.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/tabs/ShopTab.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/tabs/PrestigeTab.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/tabs/SkillTreeTab.tscn" id="4"]
[ext_resource type="PackedScene" path="res://scenes/tabs/AchievementsTab.tscn" id="5"]

[node name="BottomTabs" type="TabContainer"]
script = ExtResource("1")
custom_minimum_size = Vector2(320, 0)
size_flags_vertical = 3

[node name="Shop" parent="." instance=ExtResource("2")]

[node name="SkillTree" parent="." instance=ExtResource("4")]

[node name="Prestige" parent="." instance=ExtResource("3")]

[node name="Achievements" parent="." instance=ExtResource("5")]
```

- [ ] **Step 2: Im Editor öffnen, Tab-Layout prüfen**

Wenn TabContainer-Breite knapp wird (alle vier Labels passen nicht), in `ui/bottom_tabs.gd` (existiert, da Script in der Scene referenziert wird) ggf. `tabs_visible` / `tab_alignment` anpassen. Vermutlich passt aber alles in `custom_minimum_size=320`.

- [ ] **Step 3: Commit**

```bash
git add scenes/ui/BottomTabs.tscn
git commit -m "feat: Achievements-Tab in BottomTabs"
```

---

## Task 13: AchievementToast — Scene + Script + Queue

**Files:**
- Create: `scenes/ui/AchievementToast.tscn`, `ui/achievement_toast.gd`

- [ ] **Step 1: `ui/achievement_toast.gd`**

```gdscript
extends Control

const MAX_VISIBLE: int = 5
const FADE_IN: float = 0.3
const HOLD: float = 2.5
const FADE_OUT: float = 0.5

@onready var stack: VBoxContainer = $Stack

var _queue: Array[Dictionary] = []

func _ready() -> void:
    AchievementManager.achievement_unlocked.connect(_on_unlocked)

func _on_unlocked(id: String, stars: int) -> void:
    if stack.get_child_count() >= MAX_VISIBLE:
        _queue.append({"id": id, "stars": stars})
        return
    _spawn(id, stars)

func _spawn(id: String, stars: int) -> void:
    var data: Dictionary = AchievementManager.ACHIEVEMENTS[id]
    var panel := PanelContainer.new()
    panel.modulate = Color(1, 1, 1, 0)
    var hb := HBoxContainer.new()
    panel.add_child(hb)
    var icon := TextureRect.new()
    icon.texture = preload("res://assets/icons/star.svg")
    icon.custom_minimum_size = Vector2(20, 20)
    hb.add_child(icon)
    var label := Label.new()
    label.text = "Achievement: %s" % data["label"]
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hb.add_child(label)
    var stars_label := Label.new()
    stars_label.text = "★ +%d" % stars
    hb.add_child(stars_label)
    stack.add_child(panel)
    SoundManager.achievement()
    var tw := create_tween()
    tw.tween_property(panel, "modulate:a", 1.0, FADE_IN)
    tw.tween_interval(HOLD)
    tw.tween_property(panel, "modulate:a", 0.0, FADE_OUT)
    tw.tween_callback(func() -> void:
        panel.queue_free()
        _drain_queue()
    )

func _drain_queue() -> void:
    if _queue.is_empty(): return
    if stack.get_child_count() >= MAX_VISIBLE: return
    var next: Dictionary = _queue.pop_front()
    _spawn(next["id"], next["stars"])
```

- [ ] **Step 2: `scenes/ui/AchievementToast.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/achievement_toast.gd" id="1"]

[node name="AchievementToast" type="Control"]
anchors_preset = 12
anchor_top = 0.7
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
mouse_filter = 2

[node name="Stack" type="VBoxContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
alignment = 2
```

- [ ] **Step 3: In `Main.tscn` einbetten**

`scenes/Main.tscn` öffnen, am Ende als Child der Root-VBox eine Instanz von `AchievementToast.tscn` hinzufügen. (Im Editor: rechts-klick auf Root → "Instantiate Child Scene" → `AchievementToast.tscn`.)

- [ ] **Step 4: Manuell verifizieren**

Editor starten, ein Board lösen bis Achievement triggert. Toast erscheint, blendet aus.

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/AchievementToast.tscn ui/achievement_toast.gd scenes/Main.tscn
git commit -m "feat: AchievementToast mit Tween-Animation und Queue"
```

---

## Task 14: SoundManager.achievement()

**Files:**
- Modify: `systems/sound_manager.gd`

- [ ] **Step 1: Methode anhängen**

Nach `func prestige()` in `systems/sound_manager.gd`:

```gdscript
func achievement() -> void:
    _play_tones([784, 1047, 1568, 2093], 0.07, 0.35, "sine")
```

(Aufsteigende Sinus-Akkorde, klar unterscheidbar von combo/prestige.)

- [ ] **Step 2: Manuell anhören**

Editor starten, Achievement triggern, Sound abspielen lassen. Falls schief: Frequenzen anpassen.

- [ ] **Step 3: Commit**

```bash
git add systems/sound_manager.gd
git commit -m "feat: SoundManager.achievement()"
```

---

## Task 15: Headless-Smoketest + Build verifizieren

**Files:** (keine)

- [ ] **Step 1: Vollständigen Testlauf**

```bash
flatpak run org.godotengine.Godot --headless --add res://test -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
```

Erwartung: Alle Tests grün, inkl. den vor diesem Branch existierenden 37.

- [ ] **Step 2: Web-Export (sanity check)**

```bash
flatpak run org.godotengine.Godot --headless --export-release "Web" build/index.html
```

Wegen bekannter Crash-Issue (Memory `godot_headless_export_crash_ci.md`): Exit-Code ignorieren, stattdessen prüfen:

```bash
rtk proxy find ./build -name "index.html" -size +1c
```

Erwartung: `build/index.html` existiert und ist nicht leer.

- [ ] **Step 3: Memory aktualisieren**

`/home/alex/.claude/projects/-var-mnt-Linux-NVME-game/memory/MEMORY.md` ergänzen um Eintrag wie:

```markdown
- [Roadmap-Punkt A umgesetzt](roadmap_a_milestones.md) — Milestones/Achievements live auf docs/idle-roadmap, 10 Achievements, GameEvents-Bus eingeführt.
```

Und entsprechende Memory-Datei `roadmap_a_milestones.md` mit Kurzfassung anlegen.

- [ ] **Step 4: Final commit + PR-Vorbereitung**

```bash
git add ...
git commit -m "chore: Roadmap-A komplett (Milestones/Achievements)"
```

PR-Erstellung optional separat über `/commit-push-pr` oder manuell.

---

## Self-Review

**Spec-Coverage:**
- Counter/Event/Condition-Typen → Task 5, 6 ✓
- Save additiv → Task 7, 8 ✓
- Autoload-Reihenfolge → Task 1, 5 ✓
- Off-by-one bei lifetime_coins → Task 2 + Task 5 (PrestigeManager-Signal) ✓
- 10 Achievements im Katalog → Task 5 ✓
- AchievementsTab + Toast → Task 11, 12, 13 ✓
- Sound → Task 14 ✓
- Lock-Icon → Task 10 ✓
- Edge Case Mehrfach-Unlock idempotent → Task 5 (`unlocked.get` check) + Task 5 Test ✓
- Edge Case Unknown check → Task 6 Test ✓
- Edge Case Mehrere im selben Event → Queue in Task 13 ✓
- Headless-Tests → Task 15 ✓

**Placeholder-Scan:** Keine "TBD/TODO/implement later"-Stellen mehr.

**Type-Konsistenz:** `payload: Dictionary` durchgängig. `AchievementManager.ACHIEVEMENTS` / `.counters` / `.unlocked` / `.achievement_unlocked` Signatur in allen Tasks identisch.

**Bekannte Risiken:**
- GdUnit4-Aufruf-Syntax kann sich von oben gezeigtem Schema unterscheiden — Engineer muss `addons/gdUnit4/runtest.sh` zur Klärung lesen.
- Im Headless-Modus könnte `Time.get_ticks_msec()` mit 0 starten — daher `start_time` explizit in `_start_new_board()` setzen (Task 9).
- `Main.tscn`-Editierung in Task 13 erfordert Editor; Engineer arbeitet vermutlich eh dort.
