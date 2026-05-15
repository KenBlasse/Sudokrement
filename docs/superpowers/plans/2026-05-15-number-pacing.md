# Number-Pacing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Coin-Werte ab 1000 als kompaktes K/M/B/T-Suffix-Display anzeigen, an drei UI-Stellen konsumiert.

**Architecture:** Neuer Autoload `NumberFormat` mit reiner String-Funktion `coins(float) -> String`. Drei UI-Stellen (TopBar, Shop, MainMenu) tauschen `"%d" % int(x)` gegen `NumberFormat.coins(x)`. Stateless, headless-testbar.

**Tech Stack:** Godot 4.6.2, GDScript, GdUnit4. Spec: `docs/superpowers/specs/2026-05-15-number-pacing-design.md`.

---

## File Structure

**Create:**
- `systems/number_format.gd` — Autoload-Singleton, eine öffentliche Methode.
- `test/test_number_format.gd` — Unit-Tests aller Bereiche + Edge Cases.

**Modify:**
- `project.godot` — neuer Autoload-Eintrag.
- `ui/top_bar.gd:54` — Coin-Label-Formatierung.
- `ui/shop_tab.gd:26` — Hint-Cost-Formatierung.
- `ui/main_menu.gd:93` — Slot-Coin-Formatierung.

---

## Task 1: NumberFormat-Autoload mit Threshold-Logik

**Files:**
- Create: `systems/number_format.gd`
- Test: `test/test_number_format.gd`
- Modify: `project.godot`

- [ ] **Step 1: Failing test schreiben**

`test/test_number_format.gd`:

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
```

- [ ] **Step 2: Test laufen lassen, soll failen**

```bash
flatpak run org.godotengine.Godot --headless --path . --import 2>&1 | tail -3
flatpak run org.godotengine.Godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add res://test/test_number_format.gd --ignoreHeadlessMode 2>&1 | tail -10
```

Erwartung: FAIL — "NumberFormat not defined" oder "Invalid access".

- [ ] **Step 3: `systems/number_format.gd` anlegen**

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

- [ ] **Step 4: Autoload in `project.godot` ergänzen**

Im `[autoload]`-Block ans Ende anhängen (nach `AchievementManager`):

```ini
NumberFormat="*res://systems/number_format.gd"
```

- [ ] **Step 5: Tests laufen lassen, sollen passen**

```bash
flatpak run org.godotengine.Godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add res://test/test_number_format.gd --ignoreHeadlessMode 2>&1 | tail -10
```

Erwartung: 3 Tests pass.

- [ ] **Step 6: Commit**

```bash
git add systems/number_format.gd test/test_number_format.gd project.godot
git commit -m "feat: NumberFormat-Autoload mit Short-Scale-Suffixen ab 1K

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Tier-Coverage & Vorzeichen + Edge Cases

**Files:**
- Modify: `test/test_number_format.gd`

- [ ] **Step 1: Tests für M/B/T/Qa, negative Werte, NaN/INF anhängen**

```gdscript
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

- [ ] **Step 2: Tests laufen lassen, sollen passen** (Implementierung ist in Task 1 abgedeckt)

```bash
flatpak run org.godotengine.Godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add res://test/test_number_format.gd --ignoreHeadlessMode 2>&1 | tail -10
```

Erwartung: 10 Tests pass insgesamt.

- [ ] **Step 3: Commit**

```bash
git add test/test_number_format.gd
git commit -m "test: NumberFormat — Tier-Coverage, Vorzeichen, NaN/INF

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: TopBar-Konsument

**Files:**
- Modify: `ui/top_bar.gd`

- [ ] **Step 1: Aktuelle Stelle prüfen**

`ui/top_bar.gd:54` enthält:
```gdscript
coins_label.text = "%d" % int(new_total)
```

- [ ] **Step 2: Ersetzen**

```gdscript
coins_label.text = NumberFormat.coins(new_total)
```

- [ ] **Step 3: Headless-Smoketest: alle bestehenden Tests grün**

```bash
flatpak run org.godotengine.Godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/ --ignoreHeadlessMode 2>&1 | tail -8
```

Erwartung: alle Tests pass (Anzahl = bestehende Suite + 10 neue).

- [ ] **Step 4: Manuell verifizieren**

Editor starten, Coins farmen bis >1000 angezeigt werden (oder Save-Datei manuell editieren). TopBar zeigt `1.2K`-Format. Vor 1000 zeigt sie integer.

- [ ] **Step 5: Commit**

```bash
git add ui/top_bar.gd
git commit -m "feat(ui): TopBar nutzt NumberFormat.coins für Coin-Display

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Shop-Tab Hint-Cost-Konsument

**Files:**
- Modify: `ui/shop_tab.gd`

- [ ] **Step 1: Aktuelle Stelle prüfen**

`ui/shop_tab.gd:26` enthält:
```gdscript
return "Hint (+1 cell) — %d coins" % int(_hint_cost())
```

- [ ] **Step 2: Format-String anpassen**

```gdscript
return "Hint (+1 cell) — %s coins" % NumberFormat.coins(_hint_cost())
```

Beachte: `%d` → `%s`, weil `NumberFormat.coins()` einen String zurückgibt.

- [ ] **Step 3: Tests-Smoketest**

```bash
flatpak run org.godotengine.Godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/ --ignoreHeadlessMode 2>&1 | tail -8
```

Erwartung: alle Tests weiterhin grün.

- [ ] **Step 4: Manuell verifizieren**

Editor starten, mehrere Hints kaufen, bis `_hint_cost()` über 1000 steigt. Shop-Button zeigt `Hint (+1 cell) — 1.2K coins`.

- [ ] **Step 5: Commit**

```bash
git add ui/shop_tab.gd
git commit -m "feat(ui): Shop-Tab Hint-Cost mit NumberFormat.coins

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Main-Menu Slot-Coin-Konsument

**Files:**
- Modify: `ui/main_menu.gd`

- [ ] **Step 1: Aktuelle Stelle prüfen**

`ui/main_menu.gd:93` enthält:
```gdscript
btn.text = "Slot %d\n%d coins" % [i + 1, coins]
```

- [ ] **Step 2: Format-String anpassen**

```gdscript
btn.text = "Slot %d\n%s coins" % [i + 1, NumberFormat.coins(coins)]
```

Beachte: zweites `%d` → `%s`. Variable `coins` muss eine `float`-Variante übergeben — wenn sie schon `int` ist, ist `NumberFormat.coins(float(coins))` sauberer, aber GDScript castet `int` → `float` für den Parameter implizit. Ein Cast ist nicht zwingend; falls Editor-Warnings auftauchen, `float(coins)` ergänzen.

- [ ] **Step 3: Tests-Smoketest**

```bash
flatpak run org.godotengine.Godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/ --ignoreHeadlessMode 2>&1 | tail -8
```

Erwartung: alle Tests grün.

- [ ] **Step 4: Manuell verifizieren**

Editor starten, in einen Slot mit >1000 Coins gehen, ins Main-Menu zurück. Slot-Button zeigt `Slot 1\n12.3K coins`.

- [ ] **Step 5: Commit**

```bash
git add ui/main_menu.gd
git commit -m "feat(ui): Main-Menu Slot-Coins mit NumberFormat.coins

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: Full-Suite-Verifikation + Web-Export

**Files:** (keine Code-Änderungen)

- [ ] **Step 1: Komplette Test-Suite laufen lassen**

```bash
flatpak run org.godotengine.Godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/ --ignoreHeadlessMode 2>&1 | tail -10
```

Erwartung: alle Tests pass (bestehende Suite + 10 neue NumberFormat-Tests).

- [ ] **Step 2: Web-Export sanity check**

```bash
mkdir -p build
flatpak run org.godotengine.Godot --headless --path . --export-release "Sudokremental" build/index.html 2>&1 | tail -3
rtk proxy find ./build -name "index.html" -o -name "index.wasm" -o -name "index.pck"
```

Erwartung: `build/index.html`, `build/index.wasm`, `build/index.pck` existieren. Memory `godot_headless_export_crash_ci.md` beachten — Exit-Code wird ignoriert, nur Datei-Existenz prüfen.

- [ ] **Step 3: `.uid`-Dateien committen falls Godot welche generiert hat**

```bash
git status
git add systems/number_format.gd.uid test/test_number_format.gd.uid 2>/dev/null || true
git diff --cached --name-only
```

Wenn `.uid`-Files gestaged sind:

```bash
git commit -m "chore: .uid-files für NumberFormat

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

Sonst Step überspringen.

---

## Self-Review

**Spec-Coverage:**
- Short-Scale-Suffixe K..Dc → Task 1 (Const-Array) ✓
- Schwelle 1000 → Task 1 (`SUFFIX_THRESHOLD`) + Task 1 Test `test_threshold_boundary` ✓
- Fix 1 Nachkommastelle → Task 1 (`DECIMALS = 1`) + Task 2 Tests ✓
- TopBar-Konsument → Task 3 ✓
- Shop-Tab Hint-Cost → Task 4 ✓
- Main-Menu Slot-Coins → Task 5 ✓
- Stars/Lives/Achievement-Counter unverändert → keine Modifikation an Konsumenten dieser Werte ✓
- Negative Werte → Task 2 `test_negative_value_preserves_sign` ✓
- NaN/INF → Task 2 `test_nan_returns_zero` / `test_inf_returns_zero` ✓
- Bekannter Schönheitsfehler `999999 → "1000.0K"` → akzeptiert laut Spec, kein Test, kein Sonderfall ✓
- Headless-testbar → Task 1+2, GdUnit4 ✓

**Placeholder-Scan:** Keine TBD/TODO/implement-later. Edge-Cases in §2 der Spec sind alle abgedeckt oder explizit als out-of-scope markiert.

**Type-Konsistenz:**
- `coins(value: float) -> String` durchgängig
- Konstanten `SUFFIXES`, `SUFFIX_THRESHOLD`, `DECIMALS` stimmen mit Tests überein
- Konsumenten nutzen alle `%s` (nicht `%d`), da `coins()` einen String liefert

**Bekannte Risiken:**
- `123456.0 → "123.5K"`: Float-Rundungsverhalten von `%.1f` ist auf C-printf-Niveau; Godot-spezifisch könnte das auf bestimmten Plattformen geringfügig anders runden. Falls Test fail: erwartung anpassen oder einen `snappedf`-Schritt einführen. Sehr unwahrscheinlich.
- `Time.get_ticks_msec()` aus Plan-A: nicht relevant für diesen Plan.
- Editor-Test-Mode: keine UI-Tests; manuelle Verifikation in Tasks 3-5 als Smoketest.
