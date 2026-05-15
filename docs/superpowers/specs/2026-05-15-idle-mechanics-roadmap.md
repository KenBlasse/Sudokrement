---
typ: roadmap
status: aktiv
erstellt: 2026-05-15
pfad-entscheidung: "Aktives Puzzle-Game mit Idle-Würze"
---

# Idle-Mechanics-Roadmap

Verbindliche Reihenfolge für Incremental-Mechaniken oberhalb des bestehenden MVP.
Grundsatz-Entscheidung: **Sudoku bleibt das aktive Kern-Gameplay**, Idle-Mechaniken
sind Belohnungs- und Progression-Layer. Auto-Solver, Offline-Progress und reine
Idle-Spezialisierungen sind explizit ausgeschlossen.

Jeder Punkt bekommt vor Implementierung einen eigenen Durchlauf:
Brainstorming → Spec unter `docs/superpowers/specs/` → Plan unter
`docs/superpowers/plans/` → Umsetzung.

## Reihenfolge

### 1. A — Milestones / Achievements
Trigger-basierte Star-Drops + dauerhafte Mini-Boni. An Solving-Verhalten gekoppelt
("10 Boards solved", "Combo-Streak X", "First Hardcore"). Liefert zweite
Star-Quelle neben Prestige.

### 2. D — Number-Pacing
Suffix-Display (K/M/B/T/Qa) ab ~10⁵. Reiner UI-Polish-Layer. Vor weiteren
Currency-Layern, damit jede neue Zahl direkt sauber dargestellt wird.

### 3. B — Soft Caps
`permanent_multiplier` von linear (`+1% pro Star`) auf sub-lineare Kurve umstellen
(z.B. `1 + base*sqrt(stars/100)`). Muss **vor** C/G/F, damit nachfolgende
Mechaniken auf realistischer Skala balanciert werden.

### 4. C — Streak-Multiplier
Aufeinanderfolgende Combos innerhalb von X Sek geben Run-Mult bis ×3. Bricht bei
Fehler/Pause. Belohnt aktives Spiel ohne Idle-Spieler zu bestrafen.

### 5. G — Hint-Currency
Hints werden eigene Mini-Currency: passiv regenerieren (z.B. 1 pro 5 Min, Cap 3),
via Coins kaufbar, Skill-Tree-Node erhöht Cap. Sudoku-natürlich.

### 6. F — Technique-Recognition (USP)
Validator erkennt verwendete Solving-Technik (Naked Single, Hidden Single,
Pointing Pair, …) und vergibt Coin-Bonus pro erkannter Technik. Macht den
`solvers`-Branch des Skill-Trees zu echter Mechanik. Aufwändiger als 1–5;
eigener Spec-Durchlauf besonders wichtig.

### 7. H — Challenge-Boards
Vorgefertigte Sudokus mit Restriktionen (No Pencil-Marks, Symmetric Givens,
Killer-Variante, Speed). Belohnung: einmalig Stars + Achievement. Content-Layer
ohne neue Core-Mechanik.

### 8. E — Ascension (Meta-Prestige)
Zweite Prestige-Schicht: nach z.B. 10 Prestiges Reset gegen Diamonds.
Meta-Upgrades: "+5% Star-Yield", "Skill-Tree-Node startet entsperrt",
"Difficulty-Mult +10%". Nur sinnvoll, wenn Punkte 1–7 die Spielzeit nicht
schon hinreichend füllen — Entscheidung neu treffen, wenn dran.

## Bewusst ausgeschlossen

- **Auto-Solver** als Late-Game-Automation
- **Offline-Progress**
- **Skill-Tree-Verzweigung im "Idle vs Active"-Sinn** (Build-Specialisierung
  bleibt möglich, nicht aber Idle-fokussierte Builds)
- **Premium-Currency mit Real-Money-Vibe**
- **Producer/Manager-Pattern (Tycoon)**

## Recherche-Quellen

Roadmap basiert auf Konversations-Recherche zu gängigen Incremental-Patterns
(Kongregate-Math-Series, designthegame.com, Wikipedia-Taxonomie,
Tindalos-Games-Vergleich). Pattern-Nummerierung A–K stammt aus dem
Diskussionskontext, nicht aus einer externen Spezifikation.
