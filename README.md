# Sudokrement

Active incremental Sudoku game. Solve Sudokus → earn coins → buy upgrades → unlock skill tree → prestige for permanent multipliers.

## Run locally

```bash
flatpak run org.godotengine.Godot --path .
```

## Build for web

```bash
flatpak run org.godotengine.Godot --headless --path . --export-release "Sudokremental" build/index.html
python3 -m http.server --directory build 8000
```

Then open <http://localhost:8000>.

## Run tests

```bash
flatpak run org.godotengine.Godot --headless --path . \
  -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add test/ --ignoreHeadlessMode
```

## Design

See `docs/superpowers/specs/2026-05-13-sudokrement-design.md`.
