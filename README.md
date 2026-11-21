# Royal Arena

A 3D lane-battle card game made with **Godot 4.3** and **GDScript**. Original
characters, models, UI, sound and music. Test build: 5 cards and 5 monsters.

## Run

1. Install Godot **4.3** (standard build, not .NET).
2. Open `project.godot` in the editor (first open imports all assets), then press **F5**.
   - Main scene: `Scenes/MainMenu/MainMenu.tscn`.
   - Jump straight into a battle: open `Scenes/Battle/Battle.tscn` and press **F6**.
3. Command line: `godot --path .`

The renderer is **Compatibility** (OpenGL ES 3 / WebGL 2), which runs on PC and on most Android
phones. The window is portrait (9:16) and the layout adapts to other aspect ratios.

## How to play

- Tap a card at the bottom to select it. The monster shows up above the cards and plays
  its special animation, and the red area on the arena marks where you cannot deploy.
- Tap anywhere on your half of the arena to summon it. You can also drag the card onto the arena.
- Tap the selected card again, or right-click on PC, to cancel.
- Each card costs elixir. Elixir goes up to 10 and refills over time, at double speed
  in the last minute.
- Destroying a Princess Tower gives you 1 crown and lets you deploy in that lane's pocket.
  Destroying the King Tower gives you 3 crowns and wins the match.
- A match lasts 3 minutes. If the crowns are tied, a 1-minute sudden-death overtime follows.
  After that, the side whose weakest tower has more health wins.

## Project layout

```
Data/Cards/*.tres        card + monster data (MonsterData resources): no code needed to tune
Scenes/                  MainMenu, Battle, Arena, Monsters, Cards, UI, Shop, Victory, Defeat
Scripts/
  GameManager.gd         autoload: scene flow, battle rewards
  EconomyManager.gd      autoload: gold, gems, trophies, levels, cards, chests, quests (save file)
  BattleManager.gd       one battle: spawning, collisions, clock, crowns, result
  MonsterController.gd   monster HP, status effects, movement, attacks
  MonsterAI.gd           monster target selection + bridge pathing
  EnemyAI.gd             opponent AI (threat evaluation, counters, pushes)
  CardManager.gd         player hand, selection, drag & drop, deploy ghost
  ElixirManager.gd       elixir pool per side
  TowerController.gd     princess/king towers
  UIManager.gd           battle HUD
  Arena.gd / ArenaLayout.gd  arena visuals / gameplay geometry
  Models/                procedural stylised monster + tower models and animations
  Effects/               VFX factory, lighting, menu kingdom backdrop
  UI/                    card widget, icons, menus, popups, result screens
Assets/                  Audio (generated WAVs), Cards (portraits), Materials, UI fonts
Tools/                   ModelViewer, PortraitRenderer, Snapshot, generate_sfx.py
Tests/TestRunner.tscn    automated test suite (the 10 mandatory checks)
Docs/                    Meshy pipeline, phase reports
```

### Adding a new card

1. Duplicate a file in `Data/Cards/`, give it a new `id`, and set its stats.
2. Write a model script (`extends MonsterModel`, implement `build()` and `pose()`), or point
   **Model Glb Path** at a rigged GLB (see `Docs/MESHY_PIPELINE.md`).
3. Run `Tools/PortraitRenderer.tscn` to render the card art.

The battle, AI, menus and shop pick the card up automatically.

## Tests and QA tools

```
godot --headless --path . res://Tests/TestRunner.tscn        # exit code 0 = all checks passed
godot --path . res://Tools/Snapshot.tscn -- out=/tmp/s times=5,30 scale=2   # AI vs AI screenshots
godot --path . res://Tools/ModelViewer.tscn -- out=/tmp/m pose=attack     # model QA renders
godot --path . res://Tools/PortraitRenderer.tscn                          # re-render card art
python3 Tools/generate_sfx.py                                             # regenerate audio
```

## Credits

- Font: *Lilita One* by Juan Montoreano, SIL Open Font License (`Assets/UI/Fonts/`).
- Everything else (models, animations, VFX, UI, sound, music) was made procedurally for this project.
