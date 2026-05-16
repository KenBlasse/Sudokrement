---
typ: spec
status: aktiv
erstellt: 2026-05-16
roadmap-punkt: B
ersetzt: linearer permanent_multiplier (+1% pro Star)
---

# Soft-Caps für `permanent_multiplier`

Roadmap-Punkt B: aktuelle lineare Akkumulation des `permanent_multiplier`
(`+= gained * 0.01` pro Prestige) wird durch eine **log-basierte Kurve** über die
Lifetime-Star-Summe ersetzt. Ziel: Skala für nachfolgende Mechaniken (C/G/F)
flachhalten, ohne Spieler-Progression abzuwürgen.

## Formel

```
permanent_multiplier(total_stars) = 1.0 + 0.15 * log(1 + total_stars)
```

(`log` = natürlicher Logarithmus, identisch mit Godots `log()`.)

Referenzwerte:

| Stars  | Multiplier |
|-------:|-----------:|
|      0 |      1.00x |
|      1 |      1.10x |
|     10 |      1.36x |
|    100 |      1.69x |
|    400 |      1.90x |
|   2500 |      2.17x |
|  10000 |      2.38x |

## Speichermodell

Neue Größe `PrestigeManager.total_stars_earned: int`. Wird bei jedem Prestige
um `gained` erhöht, **nie** zurückgesetzt — Skill-Tree-Stars werden separat
verwaltet und können durch Ausgaben sinken; die Mult-Kurve aber muss monoton sein.

`Economy.permanent_multiplier` bleibt als gecachtes Feld erhalten (Read-Path-
Performance, UI-Anzeige), wird aber ausschließlich aus `total_stars_earned`
neu berechnet:

```
Economy.permanent_multiplier = 1.0 + 0.15 * log(1 + PrestigeManager.total_stars_earned)
```

Recompute-Trigger:
1. Nach jedem `PrestigeManager.prestige()`.
2. Nach `SaveSystem.load()` (siehe Migration).

## Save-Migration

Save-Schema bekommt im `PrestigeManager`-Dict einen neuen Key
`total_stars_earned`. Load-Logik:

```
if "total_stars_earned" in data:
    total_stars_earned = data["total_stars_earned"]
else:
    # alter Save: aus altem linearen Multiplier rückrechnen
    var legacy_mult = economy_data.get("permanent_multiplier", 1.0)
    total_stars_earned = int(round((legacy_mult - 1.0) * 100.0))

Economy.permanent_multiplier = 1.0 + 0.15 * log(1 + total_stars_earned)
```

Das verworfene `permanent_multiplier`-Feld im Economy-Save bleibt schreib-/
lesefähig (Forward-/Backward-Compat), wird aber beim Load durch die Kurve
überschrieben.

## Auswirkungen auf bestehende Systeme

- **PrestigeManager.prestige()**: Zeile `Economy.permanent_multiplier += gained * 0.01` weicht einer Helfer-Methode `_recompute_permanent_multiplier()`, die aus `total_stars_earned` rechnet.
- **Economy.serialize/deserialize**: unverändert (Feld bleibt im Save für Migration und externe Tools).
- **UI**: `main_menu.gd` zeigt `permanent_multiplier` weiterhin direkt an — kein UI-Change nötig.
- **Tests**: Erwartete Werte in `test_prestige.gd` und `test_economy.gd` müssen auf die neue Kurve angepasst werden. Neue Tests für Kurve, Monotonie und Save-Migration.

## Bewusst ausgeschlossen

- Keine Trennung zwischen "lifetime stars" und "skill-tree stars" auf Save-Ebene über das Notwendige hinaus — `total_stars_earned` ist ein reiner Counter, der parallel zum Skill-Tree-Pool läuft.
- Keine Run-Multiplier-Cap-Änderung (Roadmap-Punkt C wird das separat behandeln).
- Keine UI-Anzeige der Kurve oder eines "next breakpoint"-Hinweises im MVP dieses Punktes.

## Akzeptanzkriterien

1. `permanent_multiplier` folgt der Log-Formel auf 6 Nachkommastellen für `total_stars_earned ∈ {0, 1, 10, 100, 400, 2500, 10000}`.
2. Nach jedem Prestige bleibt der Multiplier monoton steigend (oder gleich, wenn 0 Stars gewonnen).
3. Alter Save (nur `permanent_multiplier=1.50`) lädt zu `total_stars_earned=50` und `permanent_multiplier=1 + 0.15*log(51) ≈ 1.590`.
4. Neuer Save (`total_stars_earned=50`) lädt identisch.
5. Alle bestehenden Tests laufen nach Anpassung der Mult-Erwartungen grün.
