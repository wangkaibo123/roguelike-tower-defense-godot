extends Node2D

## Main Game Manager for Roguelike Tower Defense

signal game_over_triggered

enum GameState { PLAYING, UPGRADING, GAME_OVER }

const BG_COLOR := Color("#8B1A1A")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")

# Spawn timing
const SPAWN_BURST_DELAY := 0.4
const SPAWN_BURST_SIZE := 3
const BURST_PAUSE := 1.5

@onready var tower: Node2D = $Tower
@onready var bullet_container: Node2D = $BulletContainer
@onready var enemy_container: Node2D = $EnemyContainer
@onready var hud: CanvasLayer = $HUD
@onready var upgrade_ui: CanvasLayer = $UpgradeUI
@onready var background: ColorRect = $Background

var game_state: GameState = GameState.PLAYING
var wave_number: int = 0
var enemies_alive: int = 0
var enemies_to_spawn: int = 0
var game_time: float = 0.0
var score: int = 0

var _spawn_queue: Array[Dictionary] = []
var _spawn_timer: float = 0.0
var _burst_counter: int = 0
var _between_bursts: bool = false
var _waiting_for_next_wave: bool = false


## Returns the current viewport size (adapts to window resize).
func _get_screen_size() -> Vector2:
	return get_viewport_rect().size


## Returns the center of the current viewport.
func _get_center() -> Vector2:
	return _get_screen_size() * 0.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Size background to viewport and connect resize
	_update_layout()
	get_tree().root.size_changed.connect(_update_layout)

	upgrade_ui.visible = false

	tower.health_changed.connect(_on_tower_health_changed)
	tower.died.connect(_on_tower_destroyed)
	upgrade_ui.upgrade_selected.connect(_on_upgrade_selected)
	hud.restart_requested.connect(_on_restart)

	hud.update_health(tower.health, tower.max_health)
	hud.update_wave(0)
	hud.update_score(0)
	hud.update_timer(0.0)

	await get_tree().create_timer(1.0).timeout
	_start_next_wave()


func _update_layout() -> void:
	var screen := _get_screen_size()
	var center := _get_center()

	# Resize background to fill viewport
	background.color = BG_COLOR
	background.position = Vector2.ZERO
	background.size = screen

	# Reposition tower to center
	tower.position = center


func _process(delta: float) -> void:
	if game_state != GameState.PLAYING:
		return

	game_time += delta
	hud.update_timer(game_time)

	if _spawn_queue.size() > 0:
		_process_spawning(delta)
	elif enemies_alive <= 0 and enemies_to_spawn <= 0 and not _waiting_for_next_wave:
		_on_wave_complete()


# --- Wave system ---

func _start_next_wave() -> void:
	_waiting_for_next_wave = false
	wave_number += 1
	var composition := _get_wave_composition(wave_number)

	enemies_to_spawn = composition.size()
	_spawn_queue = composition.duplicate()
	_spawn_timer = 0.0
	_burst_counter = 0
	_between_bursts = false

	hud.update_wave(wave_number)
	hud.show_wave_announcement(wave_number)


func _get_wave_composition(wave: int) -> Array[Dictionary]:
	var composition: Array[Dictionary] = []
	var total_enemies: int = 4 + wave * 2

	for i in total_enemies:
		var enemy_type: String = _pick_enemy_type(wave)
		composition.append({"type": enemy_type, "wave": wave})

	composition.shuffle()
	return composition


func _pick_enemy_type(wave: int) -> String:
	var roll := randf()
	if wave <= 2:
		return "triangle" if roll < 0.8 else "square"
	elif wave <= 5:
		if roll < 0.4:
			return "triangle"
		elif roll < 0.75:
			return "diamond"
		else:
			return "square"
	else:
		if roll < 0.25:
			return "triangle"
		elif roll < 0.55:
			return "diamond"
		else:
			return "square"


# --- Spawning ---

func _process_spawning(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return

	if _between_bursts:
		_between_bursts = false
		_burst_counter = 0
		_spawn_timer = 0.0
		return

	if _spawn_queue.size() > 0:
		var data: Dictionary = _spawn_queue.pop_front()
		_spawn_enemy(data)
		enemies_to_spawn -= 1
		_burst_counter += 1

		if _burst_counter >= SPAWN_BURST_SIZE and _spawn_queue.size() > 0:
			_between_bursts = true
			_spawn_timer = BURST_PAUSE
		else:
			_spawn_timer = SPAWN_BURST_DELAY


func _spawn_enemy(data: Dictionary) -> void:
	var enemy := ENEMY_SCENE.instantiate()
	enemy_container.add_child(enemy)

	enemy.global_position = _random_edge_position()

	var etype: String = data.get("type", "triangle")
	var slow_mult: float = tower.slow_factor if tower else 1.0
	enemy.setup(etype, _get_center(), slow_mult)

	var w: int = data.get("wave", 1)
	var hp_scale: float = 1.0 + (w - 1) * 0.1
	enemy.max_health *= hp_scale
	enemy.health = enemy.max_health

	enemy.died.connect(_on_enemy_died)
	enemy.reached_tower.connect(_on_enemy_reached_tower)

	enemies_alive += 1


func _random_edge_position() -> Vector2:
	var margin := 40.0
	var screen := _get_screen_size()
	var side := randi() % 4
	match side:
		0: return Vector2(randf_range(0, screen.x), -margin)
		1: return Vector2(randf_range(0, screen.x), screen.y + margin)
		2: return Vector2(-margin, randf_range(0, screen.y))
		3: return Vector2(screen.x + margin, randf_range(0, screen.y))
	return Vector2(-margin, screen.y * 0.5)


# --- Signal handlers ---

func _on_enemy_died(points: int) -> void:
	enemies_alive -= 1
	score += points
	hud.update_score(score)


func _on_enemy_reached_tower(dmg: int) -> void:
	enemies_alive -= 1
	tower.take_damage(dmg)


func _on_wave_complete() -> void:
	_waiting_for_next_wave = true
	game_state = GameState.UPGRADING
	await get_tree().create_timer(0.5).timeout
	if game_state == GameState.UPGRADING:
		upgrade_ui.show_upgrades()


func _on_upgrade_selected(upgrade_data: Dictionary) -> void:
	_apply_upgrade(upgrade_data)
	game_state = GameState.PLAYING

	await get_tree().create_timer(0.8).timeout
	if game_state == GameState.PLAYING:
		_start_next_wave()


func _on_tower_health_changed(current_hp: int, max_hp: int) -> void:
	hud.update_health(current_hp, max_hp)


func _on_tower_destroyed() -> void:
	game_state = GameState.GAME_OVER
	game_over_triggered.emit()

	for enemy in enemy_container.get_children():
		enemy.queue_free()

	hud.show_game_over(score, wave_number)


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# --- Upgrades ---

func _apply_upgrade(upgrade_data: Dictionary) -> void:
	var uid: String = upgrade_data.get("id", "")
	match uid:
		"emp":
			tower.slow_factor = maxf(tower.slow_factor - 0.15, 0.3)
		"shotgun":
			tower.bullet_count += 2
		"grenade":
			tower.has_grenade = true
		"rapid_fire":
			tower.fire_rate = maxf(tower.fire_rate * 0.8, 0.1)
		"damage_up":
			tower.bullet_damage = int(tower.bullet_damage * 1.25)
		"pierce":
			tower.bullet_pierce += 1
		"heal":
			tower.health = mini(tower.health + 30, tower.max_health)
			tower.health_changed.emit(tower.health, tower.max_health)
		"speed_bullet":
			tower.bullet_speed *= 1.3
