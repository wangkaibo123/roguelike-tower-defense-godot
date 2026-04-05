# PROJECT: Roguelike Tower Defense (Godot 4.4 Stable)

## Engine & Config
- Godot 4.4 stable, GDScript, GL Compatibility renderer
- Viewport: 480x854 (portrait), stretch mode `canvas_items`, aspect `expand`
- Main scene: `res://scenes/game.tscn`
- All UI built programmatically in code (no .tscn UI nodes)
- All visuals drawn via `_draw()` (no sprite assets)

## File Map

```
project.godot           # Engine config, input map, display settings
export_presets.cfg       # Web export preset (nothreads)
scenes/
  game.tscn             # Root scene: Game(Node2D) → Background, BgParticles, EnemyContainer, Tower, BulletContainer, HUD, UpgradeUI
  enemy.tscn            # Minimal: Node2D + script (Area2D created in code)
  bullet.tscn           # Node2D + Area2D(layer=2,mask=4) + CircleShape2D(r=5)
scripts/
  game.gd               # Game manager: state machine, wave spawning, upgrade application, signal hub
  tower.gd              # Central tower: auto-aim, shooting, range indicators, health, upgrades
  enemy.gd              # Enemy: movement toward center, types, health, damage numbers, death VFX
  bullet.gd             # Bullet: movement, collision, pierce, grenade AOE, trail, explosion VFX
  hud.gd                # HUD (CanvasLayer): health bar, timer, wave label, score, game over overlay
  upgrade_ui.gd         # Upgrade cards (CanvasLayer): 8 upgrades, random pick 3, card UI
  bg_particles.gd       # Background: floating geometric shape outlines
```

## Scene Tree (runtime)

```
Game (Node2D) [game.gd]
 ├─ Background (ColorRect) z=-10
 ├─ BgParticles (Node2D) [bg_particles.gd] z=-5
 ├─ EnemyContainer (Node2D)
 │   └─ [Enemy instances]
 ├─ Tower (Node2D) [tower.gd] position=viewport center
 │   └─ ShootTimer (Timer, created in code)
 ├─ BulletContainer (Node2D)
 │   └─ [Bullet instances]
 ├─ HUD (CanvasLayer, layer=1) [hud.gd]
 │   └─ [All UI nodes created in _ready()]
 └─ UpgradeUI (CanvasLayer, layer=100) [upgrade_ui.gd]
     └─ [Overlay + cards created in _ready()]
```

## State Machine (game.gd)

```
PLAYING → (all enemies dead) → UPGRADING → (card picked) → PLAYING → ...
PLAYING → (tower hp=0) → GAME_OVER → (restart button) → reload scene
```

## Signal Flow

```
enemy.died(points:int)        → game._on_enemy_died         → score++, hud.update_score
enemy.reached_tower(dmg:int)  → game._on_enemy_reached_tower → tower.take_damage
tower.health_changed(cur,max) → game._on_tower_health_changed → hud.update_health
tower.died()                  → game._on_tower_destroyed     → GAME_OVER, hud.show_game_over
upgrade_ui.upgrade_selected(data:Dict) → game._on_upgrade_selected → apply upgrade, next wave
hud.restart_requested()       → game._on_restart             → reload scene
hud.pause_requested()         → (not yet implemented)
```

## Collision Layers

| Layer | Bitmask | Usage |
|-------|---------|-------|
| 2     | 2       | Bullets (Area2D on bullet.tscn) |
| 3     | 4       | Enemies (Area2D created in enemy.gd _ready) |

Bullet: collision_layer=2, collision_mask=4 (detects enemies)
Enemy:  collision_layer=4, collision_mask=2 (detected by bullets)

## Enemy Types (configured in enemy.gd `setup()`)

| Type     | Speed | HP  | Size | Color   | Points | Damage | Shape    |
|----------|-------|-----|------|---------|--------|--------|----------|
| triangle | 120   | 50  | 15   | #E85D75 | 10     | 10     | 3-sided  |
| square   | 60    | 150 | 18   | #9B59B6 | 25     | 20     | 4-sided  |
| diamond  | 90    | 100 | 16   | #E67E22 | 15     | 15     | 4-sided stretched |

HP scales: `base_hp * (1.0 + (wave-1) * 0.1)`

## Tower Properties (tower.gd)

| Property      | Default | Modified by upgrade |
|---------------|---------|---------------------|
| max_health    | 100     | -                   |
| fire_rate     | 0.4s    | rapid_fire (*0.8)   |
| bullet_damage | 25      | damage_up (*1.25)   |
| bullet_speed  | 600     | speed_bullet (*1.3) |
| bullet_count  | 1       | shotgun (+2)        |
| bullet_pierce | 0       | pierce (+1)         |
| has_grenade   | false   | grenade (=true)     |
| slow_factor   | 1.0     | emp (-0.15, min 0.3)|
| base_range    | 250     | -                   |
| attack_range  | 250     | dynamic: base * (speed/600) + pierce*40, clamped 150-600 |

## Upgrade System

Upgrades defined in `upgrade_ui.gd::ALL_UPGRADES` (8 entries).
Applied in `game.gd::_apply_upgrade(data:Dict)` by matching `data.id`.

| ID           | Effect                          |
|--------------|---------------------------------|
| emp          | slow_factor -= 0.15 (min 0.3)  |
| shotgun      | bullet_count += 2               |
| grenade      | has_grenade = true              |
| rapid_fire   | fire_rate *= 0.8 (min 0.1)     |
| damage_up    | bullet_damage *= 1.25           |
| pierce       | bullet_pierce += 1              |
| heal         | health += 30 (capped)           |
| speed_bullet | bullet_speed *= 1.3             |

## Wave System (game.gd)

- Enemies per wave: `4 + wave * 2`
- Spawn: bursts of 3, 0.4s between spawns, 1.5s between bursts
- Type distribution: wave 1-2 (80%tri/20%sq), 3-5 (40%tri/35%dia/25%sq), 6+ (25%tri/30%dia/45%sq)

## Range Indicators (tower.gd `_draw_range_indicators()`)

Drawn in `_draw()` BEFORE tower body. Uses `inv_rot = -rotation` to cancel tower rotation so indicators stay world-aligned.

| Indicator | Condition | Visual |
|-----------|-----------|--------|
| Base      | always    | White dashed circle at attack_range |
| Shotgun   | bullet_count>1 | Golden filled fan/cone (rotates with tower) |
| Grenade   | has_grenade | Orange dotted ring + 4 rotating AOE preview circles |
| Pierce    | bullet_pierce>0 | Purple outer ring + outward arrow ticks |
| EMP       | slow_factor<1.0 | Blue concentric pulsing rings + snowflake markers |

## Adaptive Resolution

- `game.gd::_get_screen_size()` → `get_viewport_rect().size` (used for spawn edges, center)
- `game.gd::_update_layout()` → resize background, reposition tower; connected to `root.size_changed`
- `hud.gd::_on_resized()` → relayout top/bottom bars, labels; connected to `root.size_changed`
- `bg_particles.gd::_get_screen()` → dynamic bounds for particle wrapping
- `bullet.gd::check_bounds()` → already uses `get_viewport_rect()`

## Key Patterns for Modifications

1. **Adding a new enemy type**: Add entry in `enemy.gd::setup()` match block + add to `game.gd::_pick_enemy_type()`
2. **Adding a new upgrade**: Add dict to `upgrade_ui.gd::ALL_UPGRADES` + add match case in `game.gd::_apply_upgrade()` + add tower property if needed
3. **Adding new weapon visual**: Add draw function in `tower.gd::_draw_range_indicators()` with condition check
4. **Modifying HUD**: Edit `hud.gd` build functions; all nodes created in `_ready()`, repositioned in `_on_resized()`
5. **Bullet behavior**: Modify `bullet.gd::_process()` for movement, `_on_area_entered()` for hit logic
6. **UpgradeUI**: Method is `show_upgrades()` (no args), signal is `upgrade_selected(data:Dict)`, hide method is `hide_ui()` (NOT `hide()` — avoids CanvasLayer native override)

## Gotchas

- `upgrade_ui.gd` uses `hide_ui()` not `hide()` to avoid overriding `CanvasLayer.hide()`
- Enemy Area2D is created in code (`_ready()`), not in the .tscn file
- Bullet Area2D IS in the .tscn file (with collision shape)
- `game.gd` has `process_mode = PROCESS_MODE_ALWAYS` to work during pause
- Tower fires grenade alongside normal bullets (not instead of)
- Grenade fires at 20% of normal fire events (cooldown = fire_rate * 5)
