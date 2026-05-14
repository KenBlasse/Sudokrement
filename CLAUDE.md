# Sudokrement

Aktives Incremental-Game: Sudoku lösen → Coins → Shop/Skill-Tree/Prestige.
Web-Export (HTML5/WASM), Deploy nach GitHub Pages.

## Tech-Stack

- **Engine:** Godot 4.6.2 (Flatpak: `org.godotengine.Godot`)
- **Sprache:** GDScript
- **Tests:** GdUnit4
- **CI/CD:** GitHub Actions → GitHub Pages

## Godot-Aufruf

Godot ist als Flatpak installiert, **nicht** als nativer Befehl. Immer über Flatpak starten:

```bash
flatpak run org.godotengine.Godot                              # GUI
flatpak run org.godotengine.Godot --headless --version         # Headless
flatpak run org.godotengine.Godot --headless --export-release "Web" build/index.html
```

Optionaler Alias in `~/.bashrc`: `alias godot='flatpak run org.godotengine.Godot'`

## Projekt-Doku

- Spec: `docs/superpowers/specs/2026-05-13-sudokrement-design.md`
- MVP-Plan: `docs/superpowers/plans/2026-05-13-sudokrement-mvp.md`

## Konventionen

- UI ↔ Systems entkoppelt über Signals (kein direkter Zugriff)
- Systems sind Autoload-Singletons (`Economy`, `SkillTree`, `PrestigeManager`, `SaveSystem`)
- Logik headless testbar; UI nicht im MVP-Scope
