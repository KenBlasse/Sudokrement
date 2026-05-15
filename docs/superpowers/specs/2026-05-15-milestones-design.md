---
typ: design
status: spec
erstellt: 2026-05-15
roadmap-punkt: "A — Milestones / Achievements"
roadmap-ref: docs/superpowers/specs/2026-05-15-idle-mechanics-roadmap.md
---

# Milestones / Achievements — Design

## Zweck

Zweite Star-Quelle neben Prestige. Achievements geben dem Spieler zusätzliche
Etappenziele und belohnen sowohl quantitative Progression (X Boards gelöst) als
auch qualitatives Spielverhalten (perfekt, schnell, schwierig). Roadmap-Pfad
"aktives Puzzle-Game mit Idle-Würze".

## Anforderungen

- Achievements vergeben **ausschließlich Stars** (1–3 pro Achievement), keine
  permanenten Boni und keine Coins. Stars fließen in den bestehenden
  Skill-Tree-Pool.
- Drei Trigger-Typen: `counter`, `event`, `condition` (single-run).
- Statischer Katalog im GDScript-Dictionary (analog zu `SkillTree.NODES`).
- Persistenz im bestehenden JSON-Save-Schema, slot-aware.
- Kein retroaktives Auslösen beim Update.
- UI: Toast bei Unlock + neuer Tab "Achievements" mit kompletter Liste.
- Headless-testbare Logik (Manager separat von UI).

## Architektur

```
ui/main.gd        ─emit─▶  GameEvents (Autoload)  ─signal─▶  AchievementManager
ShopTab           ─emit─▶                                    │
PrestigeManager   ─emit─▶                                    │
SkillTree         ─emit─▶                                    ▼
                                                       SkillTree.add_stars()
                                                       achievement_unlocked signal
                                                              │
                                                              ▼
                                                       Toast-Layer + AchievementsTab
```

### Neue Komponenten

| Komponente | Pfad | Verantwortung |
|---|---|---|
| GameEvents | `systems/game_events.gd` | Reiner Signal-Bus. Keine Logik. Autoload. |
| AchievementManager | `systems/achievement_manager.gd` | Katalog, Counter-State, Unlock-Auswertung. Autoload. |
| AchievementsTab | `scenes/tabs/AchievementsTab.tscn` + `ui/achievements_tab.gd` | Liste aller Achievements. |
| AchievementToast | `scenes/ui/AchievementToast.tscn` + `ui/achievement_toast.gd` | Unlock-Toast mit Queue. |

### Bestehende Berührungen

- `ui/main.gd`: emittiert `GameEvents.board_solved`, `combo_triggered`,
  `cell_filled` an passenden Stellen (`Economy.award_*`-Aufrufe bleiben).
- `systems/board.gd`: zwei zusätzliche Felder `mistakes_this_run: int`,
  `combos_this_run: int`, in `ui/main.gd` hochgezählt.
- `systems/prestige_manager.gd`: zusätzlich `GameEvents.prestiged.emit(...)` in
  `prestige()` (bestehendes `prestiged`-Signal bleibt für die UI;
  GameEvents-Bus ist die Lese-Quelle für Achievements). Zusätzlich neues
  `signal lifetime_coins_changed(new_total: float)`, emittiert in
  `record_coins`.
- `systems/skill_tree.gd`: zusätzlich `GameEvents.skill_unlocked.emit(...)` in
  `unlock()`.
- `scenes/ui/BottomTabs.tscn`: neuer Tab "Achievements".
- `project.godot`: zwei neue Autoloads (`GameEvents` als erstes, dann
  `AchievementManager` nach `SkillTree` und `PrestigeManager`).
- `systems/sound_manager.gd`: neue Methode `achievement()`.
- Save-Aggregator (Stelle, an der `Economy.serialize()` etc. zu einem Dict
  zusammengeführt wird, vermutlich in `Main.gd` oder `MainMenu`): zusätzlich
  `AchievementManager.serialize()`/`deserialize()` einbinden.

## Datenmodell

### Katalog (in `AchievementManager`)

```gdscript
const ACHIEVEMENTS: Dictionary = {
    # Counter
    "solve_10_boards":     {"type": "counter", "counter": "boards_solved",            "threshold": 10,     "stars": 1, "label": "Routine",         "desc": "10 Boards gelöst"},
    "solve_50_boards":     {"type": "counter", "counter": "boards_solved",            "threshold": 50,     "stars": 2, "label": "Veteran",         "desc": "50 Boards gelöst"},
    "combo_100_total":     {"type": "counter", "counter": "combos_total",             "threshold": 100,    "stars": 1, "label": "Comboliebhaber",  "desc": "100 Combos ausgelöst"},
    "earn_10k_lifetime":   {"type": "counter", "counter": "lifetime_coins_observed",  "threshold": 10000,  "stars": 1, "label": "Sparbuch",        "desc": "10.000 Coins lifetime verdient"},

    # Event
    "first_hardcore":      {"type": "event", "event": "board_solved",   "check": "difficulty_hardcore", "stars": 2, "label": "Mutprobe",     "desc": "Erstes Hardcore-Board gelöst"},
    "first_prestige":      {"type": "event", "event": "prestiged",      "check": "",                    "stars": 2, "label": "Wiedergeburt", "desc": "Erstes Prestige"},
    "unlock_solvers_branch": {"type": "event", "event": "skill_unlocked", "check": "branch_solvers",   "stars": 1, "label": "Theoretiker",  "desc": "Ersten Solver-Skill freigeschaltet"},

    # Condition (single-run)
    "perfect_board":         {"type": "condition", "event": "board_solved", "check": "no_mistakes",         "stars": 1, "label": "Makellos",       "desc": "Board ohne Fehler gelöst"},
    "speedrun_60s":          {"type": "condition", "event": "board_solved", "check": "under_60s",           "stars": 2, "label": "Blitzlöser",     "desc": "Board unter 60 Sek gelöst"},
    "five_combos_one_board": {"type": "condition", "event": "board_solved", "check": "five_combos_in_board", "stars": 1, "label": "Kettenreaktion", "desc": "5 Combos in einem Board"},
}
```

### Persistenter State

```gdscript
var counters: Dictionary = {
    "boards_solved": 0,
    "combos_total": 0,
    "lifetime_coins_observed": 0,
}
var unlocked: Dictionary = {}   # achievement_id -> true
```

`lifetime_coins_observed` wird über das neue Signal
`PrestigeManager.lifetime_coins_changed` als `int(floor(...))` aktualisiert.
Eigenes Signal (statt `Economy.coins_changed` zu nutzen) vermeidet einen
Off-by-one: in `ui/main.gd` läuft `Economy.coins_changed` synchron VOR
`PrestigeManager.record_coins(...)`. Der Counter selbst ist redundant gegenüber
PrestigeManager, aber notwendig für Threshold-Vergleiche ohne
Float-Vergleichs-Problematik.

### GameEvents-Signale

```gdscript
signal board_solved(payload: Dictionary)
signal combo_triggered(combo_type: String)
signal cell_filled(correct: bool)
signal prestiged(stars_gained: int)
signal skill_unlocked(node_id: String)
```

`board_solved`-Payload:

```gdscript
{
    "difficulty": String,         # "casual"/"standard"/"hardcore"
    "time_seconds": float,
    "mistakes": int,
    "combos_in_board": int,
}
```

Dictionary-Payload statt fester Argumentliste, damit C/F/H später ergänzen
können ohne Signatur-Bruch.

### Save-Schema

```json
{
  "achievements": {
    "counters": {"boards_solved": 12, "combos_total": 47, "lifetime_coins_observed": 1830},
    "unlocked": {"solve_10_boards": true}
  }
}
```

Save-Aggregator ergänzt `data["achievements"] = AchievementManager.serialize()`;
beim Laden Spiegelaufruf.

## Datenfluss & Evaluations-Logik

### Signal-Handler

```gdscript
func _ready() -> void:
    GameEvents.board_solved.connect(_on_board_solved)
    GameEvents.combo_triggered.connect(_on_combo_triggered)
    GameEvents.prestiged.connect(_on_prestiged)
    GameEvents.skill_unlocked.connect(_on_skill_unlocked)
    PrestigeManager.lifetime_coins_changed.connect(_on_lifetime_coins_changed)

func _on_board_solved(payload: Dictionary) -> void:
    counters["boards_solved"] += 1
    _evaluate_counter("boards_solved")
    _evaluate_event("board_solved", payload)
    _evaluate_condition("board_solved", payload)

func _on_combo_triggered(_combo_type: String) -> void:
    counters["combos_total"] += 1
    _evaluate_counter("combos_total")

func _on_prestiged(_stars_gained: int) -> void:
    _evaluate_event("prestiged", {})

func _on_skill_unlocked(node_id: String) -> void:
    _evaluate_event("skill_unlocked", {"node_id": node_id})

func _on_lifetime_coins_changed(new_total: float) -> void:
    var lifetime: int = int(floor(new_total))
    if lifetime > counters.get("lifetime_coins_observed", 0):
        counters["lifetime_coins_observed"] = lifetime
        _evaluate_counter("lifetime_coins_observed")
```

### Evaluations-Methoden

```gdscript
func _evaluate_counter(counter_key: String) -> void:
    var current: int = counters.get(counter_key, 0)
    for id in ACHIEVEMENTS:
        var a: Dictionary = ACHIEVEMENTS[id]
        if a["type"] != "counter": continue
        if a["counter"] != counter_key: continue
        if unlocked.get(id, false): continue
        if current >= a["threshold"]: _unlock(id)

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
        "":                      return true
        "difficulty_hardcore":   return payload.get("difficulty", "") == "hardcore"
        "branch_solvers":        return SkillTree.NODES.get(payload.get("node_id", ""), {}).get("branch", "") == "solvers"
        "no_mistakes":           return payload.get("mistakes", -1) == 0
        "under_60s":             return payload.get("time_seconds", INF) < 60.0
        "five_combos_in_board": return payload.get("combos_in_board", 0) >= 5
        _:
            push_warning("Unknown check: %s" % check)
            return false

func _unlock(id: String) -> void:
    unlocked[id] = true
    var stars: int = ACHIEVEMENTS[id]["stars"]
    SkillTree.add_stars(stars)
    achievement_unlocked.emit(id, stars)
```

**Reihenfolge-Invariante** (Memory `signal_order_pitfall.md`): State-Mutations
IMMER vor Signal-Emission. `counters[...] += 1` vor `_evaluate_*`;
`unlocked[id] = true` vor `SkillTree.add_stars` und `achievement_unlocked.emit`.

## Persistenz, Reset, Migration

| Aktion | Counter | Unlocked |
|---|---|---|
| Prestige | bleibt | bleibt |
| Slot-Delete | reset (durch neuen Save) | reset |
| Save ohne `achievements`-Block | Defaults (0) | leer |

Retroaktives Auslösen beim Update: nein. Wer vor dem Update 50 Boards gelöst
hatte, bekommt "Veteran" erst beim 50. Board nach dem Update. Vermeidet
Toast-Schwemme beim ersten Launch.

Save-Version-Bump nicht nötig — neuer Block ist additiv, alte Saves laden mit
Defaults.

## Edge Cases

- **Mehrere Achievements im selben Event:** `_unlock` ist idempotent
  (`unlocked.get(id, false)`-Check). Toast-Queue verarbeitet mehrere hintereinander.
- **SkillTree-Branch-Check braucht `SkillTree.NODES`:** Autoload-Reihenfolge in
  `project.godot`: `GameEvents` → `Economy` → `SaveSystem` → `SkillTree` →
  `PrestigeManager` → `AchievementManager` → `SoundManager`.
- **Unbekannter Check-String** → `push_warning`, `false` zurück, kein Crash.
- **Achievement-ID in `unlocked` aber nicht mehr im Katalog** → beim Render
  ignoriert.
- **Toast-Queue-Overflow** → max 5 sichtbar, ältere Einträge werden verworfen.

## UI

### AchievementsTab

- VBoxContainer in ScrollContainer.
- Header: "Achievements (N / M)" + Gesamt-Stars-aus-Achievements-Summe.
- Pro Achievement: HBox mit Icon (`star.svg` wenn unlocked, sonst neues
  Schloss-Icon `assets/icons/lock.svg`), Label, Beschreibung, Star-Reward
  rechts ("★ 2").
- Locked-Zeilen alpha 0.4, Beschreibung trotzdem lesbar (keine
  Discovery-Mechanik).
- Sortierung: unlocked zuerst (neueste oben durch Insertion-Order in
  `unlocked`-Dictionary), dann locked in Katalog-Reihenfolge.

### AchievementToast

- PanelContainer absolut positioniert unten-mittig im `Main.tscn`,
  Theme-konform (`neon.tres`).
- Inhalt: Star-Icon + "Achievement: <label>" + "★ +<stars>" rechts.
- Fade-in 0.3s → halten 2.5s → fade-out 0.5s. Tween-basiert.
- Queue: `Array[Dictionary]`, FIFO, max 5 gleichzeitig vertikal gestapelt.
- Sound: `SoundManager.achievement()` — Asset reuse von `combo.ogg` oder
  `coin.ogg` mit Pitch-Variation; eigenes Sample optional später.

### BottomTabs

- Vierter Tab "Achievements" in `BottomTabs.tscn`. Reihenfolge:
  Shop | SkillTree | Prestige | Achievements.
- Bei Breitenproblem: Icon-only mit Tooltip — Entscheidung beim Implementieren.

## Testing

### Unit (GdUnit4, headless)

`test/test_achievement_manager.gd`:

- Counter zählt korrekt hoch bei Event.
- Achievement triggert bei genau Threshold, nicht bei Threshold-1.
- Achievement triggert nicht zweimal.
- Event-Achievement mit Check (`difficulty_hardcore`) triggert nicht bei "casual".
- Condition-Achievement mit `no_mistakes` triggert nur wenn `mistakes == 0`.
- `serialize` + `deserialize` Roundtrip behält counters + unlocked.
- Save ohne Achievement-Daten → Defaults, keine Crashes.
- `add_stars` wird mit korrektem Star-Wert aufgerufen (manueller Signal-Listener;
  `is_emitted(name)` matcht parametrisierte Signale nicht — Memory
  `gdunit4_signal_assert.md`).

`test/test_game_events.gd`:
- Signale existieren mit erwarteter Signatur.
- Payload-Dict-Pattern funktioniert (emit + connect roundtrip).

### Memory-Lessons (siehe MEMORY.md)

- `assert_int` nicht für floats — `assert_float(...).is_equal_approx` nutzen.
- `is_emitted(name)` matcht parametrisierte Signale nicht — manueller Connect.
- GDScript strict typing: `var x: int = ...` statt `var x := ...` wenn rechte
  Seite Variant ist.

### Manuell

UI-Tests gibt es im Projekt bisher keine — Toast-Verhalten, Tab-Layout,
Multi-Unlock im selben Tick manuell verifiziert.

## Out-of-Scope

- Skill-Technik-basierte Achievements (kommen mit F)
- Streak-basierte Achievements (kommen mit C)
- Hint-Currency-bezogene Achievements (kommen mit G)
- Retroaktive Auslösung beim Update
- Discord/Steam-Achievement-Bridge
- Achievement-Sharing/Screenshots
