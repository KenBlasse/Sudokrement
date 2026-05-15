---
typ: design
status: spec
erstellt: 2026-05-15
roadmap-punkt: "D — Number-Pacing"
roadmap-ref: docs/superpowers/specs/2026-05-15-idle-mechanics-roadmap.md
---

# Number-Pacing — Design

## Zweck

Kurzform-Display für Coin-Werte ab 1.000: `1.2K`, `12.3M`, `1.4T` usw. Reiner
UI-Polish-Layer. Macht große Zahlen kompakt und vermittelt Idle-Game-Feel.
Kein Einfluss auf Logik, Persistenz oder Balancing.

## Anforderungen

- Suffix-Schema: Short-Scale (K/M/B/T/Qa/Qi/Sx/Sp/Oc/No/Dc), englische Suffixe.
- Schwelle: ab `1000.0`. Werte darunter: integer-cast, kein Suffix.
- Präzision im Suffix-Bereich: fix **1 Nachkommastelle**.
- Anwendungsorte:
  - TopBar-Coin-Display (`ui/top_bar.gd:54`)
  - Shop-Tab Hint-Cost (`ui/shop_tab.gd:26`)
  - Main-Menu Slot-Coins (`ui/main_menu.gd:93`)
- Nicht betroffen: Stars, Lives, Achievement-Counter, Skill-Tree-Costs.
- Headless-testbar (reine String-Funktion ohne Engine-Abhängigkeit).

## Architektur

Neues Autoload `NumberFormat` (`systems/number_format.gd`). Eine öffentliche
Methode `coins(value: float) -> String`. Konsumenten ersetzen `"%d" % int(x)`
durch `NumberFormat.coins(x)`.

```
ui/top_bar.gd       ─▶  NumberFormat.coins(coins)
ui/shop_tab.gd      ─▶  NumberFormat.coins(hint_cost)
ui/main_menu.gd     ─▶  NumberFormat.coins(slot_coins)
```

### Neue Datei

| Pfad | Verantwortung |
|---|---|
| `systems/number_format.gd` | Suffix-Formatierung, stateless. Autoload. |
| `test/test_number_format.gd` | Unit-Tests aller Bereiche + Edge Cases. |

### Bestehende Berührungen

- `ui/top_bar.gd:54` — eine Zeile Ersatz
- `ui/shop_tab.gd:26` — eine Zeile, Format-String anpassen
- `ui/main_menu.gd:93` — eine Zeile, Format-String anpassen
- `project.godot` `[autoload]` — `NumberFormat` ergänzen

### Autoload-Position

Ans Ende, nach `AchievementManager`. Keine Abhängigkeiten zu anderen
Autoloads, Reihenfolge egal.

## API

```gdscript
extends Node

const SUFFIXES: Array[String] = [
    "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"
]
const SUFFIX_THRESHOLD: float = 1000.0
const DECIMALS: int = 1

func coins(value: float) -> String:
    if is_nan(value) or is_inf(value):
        return "0"
    var abs_value: float = abs(value)
    if abs_value < SUFFIX_THRESHOLD:
        return "%d" % int(value)
    var tier: int = int(floor(log(abs_value) / log(SUFFIX_THRESHOLD)))
    tier = clamp(tier, 0, SUFFIXES.size() - 1)
    var scaled: float = value / pow(SUFFIX_THRESHOLD, tier)
    return "%.*f%s" % [DECIMALS, scaled, SUFFIXES[tier]]
```

`log(x) / log(1000.0)` ist die generische Tier-Berechnung (entspricht
`log_1000(x)`). Negative Werte werden über `abs_value` für die Tier-Wahl
genutzt, das Vorzeichen bleibt im finalen `scaled` enthalten (`-1500/1000 =
-1.5` → `"-1.5K"`).

## Edge Cases

| Input | Output | Begründung |
|---|---|---|
| `0.0` | `"0"` | Unter Threshold, integer-cast |
| `999.0` | `"999"` | Unter Threshold |
| `999.9` | `"999"` | `int()` truncated |
| `1000.0` | `"1.0K"` | Threshold-Übergang |
| `9999.0` | `"10.0K"` | `%.1f` rundet auf |
| `12345.0` | `"12.3K"` | Standard |
| `999999.0` | `"1000.0K"` | Bekannter Schönheitsfehler am K↔M-Übergang; akzeptiert |
| `1_000_000.0` | `"1.0M"` | Tier-Wechsel |
| `3_200_000_000.0` | `"3.2B"` | B-Tier |
| `1_400_000_000_000.0` | `"1.4T"` | T-Tier |
| `-1500.0` | `"-1.5K"` | Negatives: Vorzeichen erhalten |
| `NaN` | `"0"` | Defensiv |
| `INF` / `-INF` | `"0"` | Defensiv |
| `> 10³³` (über Dc) | clamped auf Dc, `scaled` wächst | Praxis nie erreicht |

## Konsumenten — konkrete Patches

`ui/top_bar.gd:54` (alt → neu):
```gdscript
coins_label.text = "%d" % int(new_total)
# →
coins_label.text = NumberFormat.coins(new_total)
```

`ui/shop_tab.gd:26`:
```gdscript
return "Hint (+1 cell) — %d coins" % int(_hint_cost())
# →
return "Hint (+1 cell) — %s coins" % NumberFormat.coins(_hint_cost())
```

`ui/main_menu.gd:93`:
```gdscript
btn.text = "Slot %d\n%d coins" % [i + 1, coins]
# →
btn.text = "Slot %d\n%s coins" % [i + 1, NumberFormat.coins(coins)]
```

## Testing

`test/test_number_format.gd` (GdUnit4, headless):

```gdscript
extends GdUnitTestSuite

func test_under_threshold_no_suffix() -> void:
    assert_str(NumberFormat.coins(0.0)).is_equal("0")
    assert_str(NumberFormat.coins(42.0)).is_equal("42")
    assert_str(NumberFormat.coins(999.0)).is_equal("999")
    assert_str(NumberFormat.coins(999.9)).is_equal("999")

func test_threshold_boundary() -> void:
    assert_str(NumberFormat.coins(1000.0)).is_equal("1.0K")

func test_k_range() -> void:
    assert_str(NumberFormat.coins(1234.0)).is_equal("1.2K")
    assert_str(NumberFormat.coins(12345.0)).is_equal("12.3K")
    assert_str(NumberFormat.coins(123456.0)).is_equal("123.5K")

func test_m_tier() -> void:
    assert_str(NumberFormat.coins(1_000_000.0)).is_equal("1.0M")
    assert_str(NumberFormat.coins(2_500_000.0)).is_equal("2.5M")

func test_b_tier() -> void:
    assert_str(NumberFormat.coins(3_200_000_000.0)).is_equal("3.2B")

func test_t_tier() -> void:
    assert_str(NumberFormat.coins(1_400_000_000_000.0)).is_equal("1.4T")

func test_qa_tier() -> void:
    assert_str(NumberFormat.coins(1_000_000_000_000_000.0)).is_equal("1.0Qa")

func test_negative_value_preserves_sign() -> void:
    assert_str(NumberFormat.coins(-1500.0)).is_equal("-1.5K")

func test_nan_returns_zero() -> void:
    assert_str(NumberFormat.coins(NAN)).is_equal("0")

func test_inf_returns_zero() -> void:
    assert_str(NumberFormat.coins(INF)).is_equal("0")
    assert_str(NumberFormat.coins(-INF)).is_equal("0")
```

UI-Patches werden nicht eigens getestet — wir verlassen uns darauf, dass
`NumberFormat.coins()` korrekt ist und Konsumenten den Output unverändert
durchreichen.

## Out-of-Scope

- Locale-Sensitivity (immer Punkt-Dezimaltrenner)
- Stars/Lives/Achievement-Counter-Formatierung
- Engineering-Notation jenseits Dc
- Configurable Precision (immer 1 Nachkommastelle)
- Tausender-Trennzeichen für Werte unter 1K (999 statt 999 — bleibt)
- Animations-Tweens beim Wert-Wechsel (separates Polish-Feature, nicht D)
