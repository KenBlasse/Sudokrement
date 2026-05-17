---
typ: spec
status: aktiv
roadmap-punkt: C
erstellt: 2026-05-17
---

# Streak-Multiplier (Roadmap-Punkt C)

Aufeinanderfolgende Combos innerhalb eines Zeitfensters geben einen
Run-Multiplier bis ×3. Bricht bei Fehler oder Pause. Belohnt aktives,
flüssiges Solving ohne reine Idle-Spieler einseitig zu bevorzugen.

## Mechanik

- **Trigger:** jedes `GameEvents.combo_triggered(combo_type)` (row, column,
  block) erhöht `count` um 1. Cell-Fills und Board-Complete zählen nicht.
- **Zeitfenster:** 15.0 Sekunden ab letztem Combo-Tick. Läuft das Fenster
  ohne neuen Combo ab, resettet der Streak.
- **Kurve:** `multiplier = min(1.0 + count * 0.2, 3.0)`. Cap bei count=10
  (×3.0). `count` läuft über 10 hinaus weiter (für künftige Achievements
  wie "Streak 25"); `multiplier` bleibt auf 3.0 geklippt.
- **Bruch-Bedingungen:**
  - `GameEvents.cell_filled(false)` (falsche Eingabe)
  - 15.0 s ohne neuen Combo
  - `GameEvents.prestiged` (Run-Reset)
- **Kein Bruch durch:** korrekte Cell-Fills, Hint-Käufe, Pause-Menü-Öffnen,
  Board-Complete (Streak läuft über Board-Grenzen hinweg, solange das
  Fenster läuft).
- **Persistenz:** keine. Bei Game-Start beginnt der Streak bei 0 / ×1.0.

## Komponenten

### Neu: `systems/streak_manager.gd` (Autoload `StreakManager`)

Felder:
- `count: int = 0`
- `multiplier: float = 1.0`
- `time_left: float = 0.0`

Konstanten:
- `WINDOW_SEC: float = 15.0`
- `STEP: float = 0.2`
- `CAP_COUNT: int = 10`
- `CAP_MULT: float = 3.0`

Signal:
- `streak_changed(count: int, multiplier: float, time_left: float, window: float)`

Methoden:
- `_ready()` — verbindet `GameEvents.combo_triggered`, `GameEvents.cell_filled`, `GameEvents.prestiged`.
- `_process(delta: float)` — ruft `_tick(delta)`.
- `_tick(delta: float) -> void` — public/testbar; early-return wenn `count == 0`. Sonst `time_left -= delta`; bei `<= 0` → `_reset()`.
- `_on_combo(_combo_type: String) -> void` — `count += 1`, `time_left = WINDOW_SEC`, `multiplier = min(1.0 + count * STEP, CAP_MULT)`, `Economy.run_multiplier = multiplier`, emit.
- `_on_cell_filled(correct: bool) -> void` — wenn `not correct`: `_reset()`.
- `_on_prestiged(_stars_gained: int) -> void` — `_reset()`.
- `_reset() -> void` — `count = 0`, `multiplier = 1.0`, `time_left = 0.0`, `Economy.run_multiplier = 1.0`, emit.

### Neu: `ui/streak_indicator.tscn` + `ui/streak_indicator.gd`

In `ui/top_bar.tscn` eingebunden. Inhalt:
- Label: `Streak {count} ×{multiplier mit 1 Nachkommastelle}`
- ProgressBar: `value = time_left`, `max_value = window` — schrumpft sichtbar.
- Bei `count == 0`: gesamtes Indicator unsichtbar (`visible = false`).
- Hört `StreakManager.streak_changed`.

### Geändert: `ui/sudoku_board.gd`

Beim bestehenden lokalen `cell_filled`-Emit zusätzlich auf den globalen Bus:
`GameEvents.cell_filled.emit(correct)`. Bus-Fix — das Signal existiert in
`game_events.gd`, wird aber nirgendwo emittiert.

### Geändert: `ui/main.gd`

In den drei Combo-Branches (row, column, block) Reihenfolge umdrehen:
**erst** `GameEvents.combo_triggered.emit(...)` (damit `StreakManager`
`Economy.run_multiplier` aktualisiert), **dann** `Economy.award_combo(...)`
(damit der Award den neuen Multiplier nutzt). Aktuell ist die Reihenfolge
umgekehrt.

### Geändert: `project.godot`

`StreakManager` als Autoload registrieren. Reihenfolge: nach `Economy` und
nach `GameEvents`, damit `_ready` Zugriff auf beide hat.

## Datenfluss

```
Combo gefeuert (ui/main.gd):
  GameEvents.combo_triggered.emit("row")
    → StreakManager._on_combo("row")
      → count++, time_left = 15.0
      → multiplier = clamp(1 + count*0.2, ..., 3.0)
      → Economy.run_multiplier = multiplier
      → streak_changed.emit(...)
        → StreakIndicator updates Label + Bar
  Economy.award_combo("row")  ← nutzt neuen run_multiplier

Falsche Eingabe (ui/sudoku_board.gd):
  GameEvents.cell_filled.emit(false)
    → StreakManager._on_cell_filled(false)
      → _reset()

Zeitablauf (StreakManager._process):
  time_left -= delta
  wenn time_left <= 0 → _reset()

Prestige:
  GameEvents.prestiged.emit(stars)
    → StreakManager._on_prestiged(...)
      → _reset()
```

## Edge-Cases

- **Multi-Combo in einem Frame** (z.B. Row+Column+Block gleichzeitig
  geschlossen): 3 `combo_triggered`-Events kommen sequenziell an;
  `count` steigt um 3, `time_left` wird mehrfach auf 15.0 gesetzt,
  jeder `award_combo`-Call sieht den jeweils aktuellen `multiplier` —
  korrekt eskalierende Belohnung.
- **hide_wrong-Option am Board:** Streak-Bruch greift trotzdem, weil das
  Board die Korrektheit kennt (logik-unabhängig vom visuellen Hide).
- **Cap-Verhalten:** `count > 10` lassen wir bewusst weiterlaufen — billiger
  Hook für spätere Achievements; `multiplier` bleibt geklippt.
- **Early-Return im Tick:** wenn `count == 0`, kein Tick-Decrement und kein
  Re-Emit — vermeidet unnötigen Signal-Spam pro Frame.

## Tests

GdUnit4, headless, neue Datei `test/test_streak_manager.gd`. `before_test`
setzt `StreakManager` und `Economy.run_multiplier` zurück (siehe Memory
`test_isolation_autoload_side_effects.md`).

- combo erhöht count, multiplier korrekt
- Cap bei multiplier=3.0, count läuft weiter
- `cell_filled(false)` resettet
- `cell_filled(true)` resettet **nicht**
- `_tick(16.0)` ohne combo resettet
- combo refresht das Fenster (combo → tick(10) → combo → tick(10) → noch aktiv)
- `prestiged` resettet
- combo aktualisiert `Economy.run_multiplier`; reset setzt zurück auf 1.0
- `streak_changed`-Signal feuert mit korrekten Payload-Werten (manueller
  Connect, siehe Memory `gdunit4_signal_assert.md`)
- Integration: combo + sofortiger `award_combo` ergibt erwartetes Coin-Delta
  (Reihenfolge: streak-update vor award)

Ziel: 74/74 → 84/84 Tests grün.

## Out of Scope

- Visualisierung von Streak-Bruch (Shake/Toast) — kann als späterer Polish
  nachgereicht werden, nicht Teil dieses Punkts.
- Streak-Achievements ("Streak 10", "Streak 25") — separat planbar, sobald
  diese Mechanik live ist; `count` läuft bewusst weiter, um den Hook offen
  zu halten.
- Skill-Tree-Nodes auf Streak-Parameter (z.B. "+5s Window") — nicht im
  Scope dieser Roadmap-Stufe.

## Verwandt

- Roadmap: `docs/superpowers/specs/2026-05-15-idle-mechanics-roadmap.md`
- Vorheriger Punkt B: `docs/superpowers/specs/2026-05-16-soft-caps-design.md`
- Konvention "UI ↔ Systems über Signals": `CLAUDE.md`
