# Sudokrement — Design-Spec

**Datum:** 2026-05-13
**Autor:** Alex + Claude
**Status:** Entwurf, bereit für Implementations-Plan

## Übersicht

**Sudokrement** ist ein aktives Incremental-Game, bei dem klassisches Sudoku-Lösen die Kernmechanik ist und Incremental-Elemente (Currency, Skill-Tree, Prestige) als Belohnungs- und Progressionssystem dienen. Spieler lösen Sudokus, verdienen Coins, kaufen temporäre Upgrades, schalten dauerhaft Solver-Techniken und schwerere Tiers frei und prestigen für permanente Multiplikatoren.

**Plattform:** Web (HTML5/WebAssembly), gebaut mit Godot 4.x.

**Zielspieler:** Sudoku-Fans, die Progressions-Belohnungen mögen. Incremental-Spieler, die aktiveres Gameplay als reine Klicker suchen.

## Kernkonzept und Gameplay-Loop

1. Spieler wählt Difficulty-Modus (Casual / Standard / Hardcore) mit unterschiedlichen Coin-Multiplikatoren.
2. Ein Sudoku-Board wird generiert (Tier-abhängig — Start: Easy 9x9).
3. Spieler löst per Tastatur oder Zahl-Buttons und verdient Coins:
   - Pro korrekte Zelle: 1 Coin × Multiplikatoren
   - Pro vollständige Reihe/Spalte/3x3-Block: +10 Combo-Coins
   - Pro vollständiges Board: +100 Coins + Speed-Bonus
4. Coins werden für Sofort-Upgrades im Shop ausgegeben (Hints, Auto-Notes, Multiplier).
5. Skill-Tree-Punkte aus gelösten Boards schalten permanente Mechaniken frei.
6. Prestige-Reset (verfügbar nach 25 gelösten Boards einer Schwierigkeit) gibt Stars und permanente Multiplikatoren, schaltet höhere Tiers frei.

### Schwierigkeits-Tiers (Progression via Skill-Tree/Prestige)

Easy 9x9 → Medium 9x9 → Hard 9x9 → Expert 9x9 → Killer-Sudoku → 16x16

### Difficulty-Modus-Multiplikatoren

| Modus | Coin-Mult | Fehler-Verhalten |
|---|---|---|
| Casual | ×1.0 | Falsche Eingabe wird rot, kein Penalty, beliebig korrigierbar |
| Standard | ×1.5 | 3 Leben pro Board, beim 4. Fehler Board verloren (keine Coins) |
| Hardcore | ×2.5 | Keine Live-Validierung, Prüfung erst beim Komplettieren |

## Architektur

### Engine und Sprache

- Godot 4.x mit GDScript
- Export-Target: HTML5/WebAssembly
- Hosting: GitHub Pages

### Szenen-Struktur

```
Main.tscn                         # Root, lädt Autoloads
├── UI/
│   ├── TopBar.tscn               # Coins, Coins/s, Prestige, Timer, Difficulty-Selector
│   ├── SudokuBoard.tscn          # Generisches Grid, skaliert auf 4x4 bis 16x16
│   ├── NumberPad.tscn            # 1-N Buttons, Notes-Toggle, Erase
│   └── BottomTabs.tscn           # Tab-Container: Shop, Bots, Skill-Tree, Prestige
└── Systems/                      # Reines Logik-Layer, keine UI
    ├── BoardGenerator.gd         # Erzeugt valide Sudokus pro Tier
    ├── Validator.gd              # Prüft Eingaben, erkennt Combos
    ├── Economy.gd                # Currency, Multiplikatoren, Combo-Logik
    ├── SkillTree.gd              # Knoten, Voraussetzungen, Effekte
    ├── PrestigeManager.gd        # Reset-Logik, Stars-Berechnung
    └── SaveSystem.gd             # JSON-Persistenz nach user:// (IndexedDB im Browser)
```

### Autoload-Singletons

`Economy`, `SkillTree`, `PrestigeManager`, `SaveSystem` werden als Autoloads registriert. So sind Game-State und Currency global zugreifbar, ohne durch die Szenen-Hierarchie reichen zu müssen.

### Kopplung über Signals

UI-Komponenten kommunizieren nicht direkt mit Systems. Stattdessen:

- `SudokuBoard` emittiert `cell_filled(row, col, value, is_correct)`
- `Validator` hört darauf, emittiert `combo_completed(type, multiplier)`
- `Economy` hört auf Validator und emittiert `coins_changed(new_total)`
- `TopBar` und `BottomTabs` hören auf `coins_changed`

Vorteil: Komponenten sind isoliert testbar und können einzeln getauscht werden.

### Datenmodell

```gdscript
class_name Board
var size: int                    # 9 oder 16
var cells: Array                 # 2D-Array von Cell
var solution: Array              # 2D-Array der Lösung
var difficulty: String           # "easy", "medium", "hard", "expert", "killer", "16x16"
var start_time: float            # für Speed-Bonus
var lives_left: int              # für Standard-Modus

class_name Cell
var value: int                   # 0 = leer, sonst 1..size
var given: bool                  # vom Generator gesetzt, nicht editierbar
var notes: Array                 # Set von Pencil-Marks
var locked: bool                 # vom Bot/Hint gesetzt, nicht überschreibbar
```

Persistierter GameState (JSON):

```json
{
  "version": 1,
  "coins": 0,
  "prestige_currency": 0,
  "prestige_count": 0,
  "unlocked_tiers": ["easy"],
  "skill_tree": { "naked_single": false, "hidden_single": false },
  "permanent_multiplier": 1.0,
  "boards_solved": { "easy": 0, "medium": 0 },
  "current_board": null,
  "settings": { "difficulty_mode": "casual" }
}
```

## Komponenten im Detail

### BoardGenerator

- Verantwortlich: Erzeugt valide, eindeutig lösbare Sudoku-Boards pro Tier.
- Strategie für MVP: Backtracking-Generator in GDScript. Fallback bei Performance-Problemen im Browser: Set vorgenerierter Boards aus JSON laden.
- Schwierigkeit wird über Anzahl der gegebenen Zellen gesteuert (Easy: ~40, Hard: ~25, Expert: ~17–22).

### Validator

- Prüft einzelne Zell-Eingaben gegen `Board.solution`.
- Erkennt completed rows/columns/3x3-blocks und emittiert `combo_completed`.
- Im Hardcore-Modus deaktiviert (Validierung nur am Board-Ende).

### Economy

- Hält `coins`, berechnet Combo-Stacking: `award = base × difficulty_mult × permanent_mult × shop_run_mult`.
- Combo-Boni werden auf alle Zellen der vollendeten Linie zurück-applied (oder als Pauschal-Bonus +10/+20/+100).
- Shop-Logik: Preis-Skalierung nach Kauf, Effekt-Anwendung.

### SkillTree

- Knoten in drei Branches: Solvers, Economy, Progression.
- Voraussetzungen über `requires`-Liste (Knoten X braucht Knoten Y).
- Kosten in Stars (Prestige-Currency).
- Effekte werden bei Anwendung als Modifier in Economy/Validator/etc. eingespeist.

### PrestigeManager

- Verfügbar nach 25 gelösten Boards der aktuellen Schwierigkeit (konfigurierbar pro Tier).
- Bei Prestige-Trigger: Stars-Berechnung, Reset der temporären States, Increment von `prestige_count`.
- `stars_gained = floor(sqrt(total_coins_lifetime / 1000))`
- Pro Star: +1% permanenter Coin-Multiplikator + 1 Skill-Tree-Punkt.

### SaveSystem

- JSON-Serialisierung des GameState, Schreiben nach `user://save.json`.
- Im Browser landet das in IndexedDB (Godot-internes Verhalten).
- Autosave alle 30 Sekunden + bei jedem Prestige + bei Board-Komplettierung.
- UI: "Export Save" → JSON-Download via `JavaScriptBridge`, "Import Save" → File-Upload.
- Versions-Feld erlaubt zukünftige Migrationen.

## UI/UX

### Layout (Vertikal mit Tabs, gewählt)

```
┌─────────────────────────────────────────┐
│  TopBar: 💰 Coins  ⚡ /s  ⭐ Prestige  ⏱ │
├─────────────────────────────────────────┤
│                                         │
│            Sudoku-Board (zentriert)     │
│                                         │
│            NumberPad: 1 2 3 4 5 ...     │
│                                         │
├─────────────────────────────────────────┤
│  [Shop] [Bots] [Skill-Tree] [Prestige]  │
│  ↓ aktiver Tab-Inhalt                   │
└─────────────────────────────────────────┘
```

### Input

Hybrid-Eingabe:

- Desktop: Zelle klicken, Zahl per Tastatur (1–9) eingeben, Backspace zum Löschen
- Mobil: Zelle tippen, Zahl aus NumberPad wählen
- Notes-Modus: Toggle via N-Taste oder Notes-Button → Eingaben werden zu Pencil-Marks

### Visuelles Feedback

- Korrekte Eingabe: Zelle bleibt normal, kurze grüne Pulsierung
- Falsche Eingabe (Casual/Standard): Zelle wird rot, im Standard-Modus -1 Leben
- Combo: Reihe/Spalte/Block kurz aufleuchten + Coin-Indicator fliegt zur TopBar

## Testing-Strategie

GdUnit4 für Unit-Tests der Game-Logik:

```
test/
├── test_board_generator.gd     # Boards: valide, lösbar, eindeutig
├── test_validator.gd            # Korrekt/falsch, Combo-Erkennung
├── test_economy.gd              # Award-Formel, Combo-Stacking
├── test_skill_tree.gd           # Knoten-Voraussetzungen, Effekt-Anwendung
├── test_prestige.gd             # Reset-Logik, Stars-Formel
└── test_save_system.gd          # Round-Trip: save → load → identisch
```

**Nicht testbar im MVP:** UI-Rendering, Animationen, Touch-Events. Bei Bedarf später per PlayGodot E2E.

**Run:**
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --run-tests
```

## Build & Deployment

**Lokaler Web-Export:**
```bash
godot --headless --export-release "Web" build/index.html
```

**CI/CD via GitHub Actions** auf jeden Push zu `main`:

1. GdUnit4-Tests
2. Bei grün: Web-Export bauen
3. Deploy nach GitHub Pages

**Deployment-Ziel:** GitHub Pages — kostenlos, statisches Hosting, Auto-Deploy.

**Risiken (Web):**

- Godot-Web-Builds groß (~30–50 MB initial) → mit Loading-Screen abfedern
- Kein Threading → BoardGenerator muss schnell sein, Fallback auf JSON-Boards
- IndexedDB-Save kann durch Browser-Cleanup verloren gehen → Export/Import als Backup

## Implementations-Reihenfolge (grobe MVP-Skizze)

1. **Sudoku-Core:** Board-Datenstruktur, Generator, Validator (mit Unit-Tests)
2. **UI-Skelett:** SudokuBoard.tscn, NumberPad.tscn, Input-Handling, ein 9x9-Easy-Board spielbar
3. **Economy:** Coin-Award pro Zelle + Combo-Boni, TopBar
4. **Shop:** BottomTabs mit Shop-Items, Käufe wirken auf laufenden Run
5. **Save/Load:** Persistenz inkl. Export/Import
6. **Skill-Tree:** Tab + erste Solver-Knoten + Economy-Knoten
7. **Prestige:** Reset-Logik, Stars-Vergabe, Multiplikator
8. **Tier-Progression:** Medium/Hard freischalten, Generator-Varianten
9. **Polish:** Animationen, Sound, Tutorial
10. **CI/CD + Deploy:** GitHub Actions, GitHub Pages

## Offene Fragen / Nice-to-haves (außerhalb MVP)

- Sound-Effekte und Musik (später)
- Achievements/Statistiken
- Killer-Sudoku-Generator (komplexer als Standard)
- 16x16-Generator-Performance
- Cloud-Save (z.B. via Supabase Auth) — nur falls Bedarf
- Soft-Theme / Light/Dark-Toggle

## Geschätzte Komplexität

- Sudoku-Core + UI: 2–3 Tage solide Arbeit
- Economy + Shop + Save: 2 Tage
- Skill-Tree + Prestige: 2–3 Tage
- Tiers + Polish + Deploy: 2–3 Tage

**Gesamt-MVP:** ~10 Arbeitstage als Solo-Projekt bei moderater Geschwindigkeit.
