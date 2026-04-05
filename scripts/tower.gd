extends Node2D
## Central tower that auto-aims and fires at the nearest enemy.

# --- Signals ---
signal health_changed(current: int, max_val: int)
signal died()

# --- Preloads ---
var BulletScene: PackedScene = preload("res://scenes/bullet.tscn")

# --- Exports / Properties ---
@export var max_health: int = 100
@export var fire_rate: float = 0.4
@export var bullet_damage: int = 25
@export var bullet_speed: float = 600.0
@export var rotation_speed: float = 8.0

var health: int = 100

# Upgrade-driven properties
var bullet_count: int = 1
var bullet_pierce: int = 0
var has_grenade: bool = false
var slow_factor: float = 1.0

# Internal state
var _target: Node2D = null
var _can_shoot: bool = true
var _grenade_cooldown: float = 0.0

@onready var shoot_timer: Timer = Timer.new()

# --- Lifecycle ---

func _ready() -> void:
	health = max_health

	shoot_timer.name = "ShootTimer"
	shoot_timer.wait_time = fire_rate
	shoot_timer.one_shot = true
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	add_child(shoot_timer)


func _process(delta: float) -> void:
	_target = find_nearest_enemy()

	if _target and is_instance_valid(_target):
		var direction: float = global_position.direction_to(_target.global_position).angle()
		rotation = lerp_angle(rotation, direction, rotation_speed * delta)

		if _can_shoot:
			shoot()

	# Grenade cooldown tracking
	if has_grenade and _grenade_cooldown > 0.0:
		_grenade_cooldown -= delta

	queue_redraw()


func _draw() -> void:
	# --- Tower body ---
	# Outer outline ring
	draw_circle(Vector2.ZERO, 33.0, Color(0.3, 0.3, 0.3))
	# Main body
	draw_circle(Vector2.ZERO, 30.0, Color("#2A2A2A"))
	# Inner highlight ring
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 48, Color(0.25, 0.25, 0.25), 1.5)

	# --- Cannon barrel (drawn in local space, pointing right = 0 rad) ---
	var barrel_length: float = 38.0
	var barrel_width: float = 10.0
	var barrel_offset: float = 12.0
	var barrel_rect := Rect2(
		Vector2(barrel_offset, -barrel_width * 0.5),
		Vector2(barrel_length, barrel_width)
	)
	draw_rect(barrel_rect, Color(0.22, 0.22, 0.22))
	# Barrel outline
	draw_rect(barrel_rect, Color(0.35, 0.35, 0.35), false, 1.5)

	# Muzzle flash hint (small lighter cap at barrel tip)
	var tip_rect := Rect2(
		Vector2(barrel_offset + barrel_length - 4.0, -barrel_width * 0.5),
		Vector2(4.0, barrel_width)
	)
	draw_rect(tip_rect, Color(0.4, 0.4, 0.4))

	# --- Health ring ---
	if health < max_health:
		var health_ratio: float = float(health) / float(max_health)
		var arc_end: float = TAU * health_ratio
		var health_color := Color.GREEN.lerp(Color.RED, 1.0 - health_ratio)
		draw_arc(Vector2.ZERO, 36.0, -PI * 0.5, -PI * 0.5 + arc_end, 48, health_color, 2.5)


# --- Enemy Detection ---

func find_nearest_enemy() -> Node2D:
	var enemy_container: Node = get_parent().get_node_or_null("EnemyContainer")
	if not enemy_container:
		return null

	var nearest: Node2D = null
	var nearest_dist_sq: float = INF

	for enemy in enemy_container.get_children():
		if not is_instance_valid(enemy):
			continue
		if enemy is Node2D:
			var dist_sq: float = global_position.distance_squared_to(enemy.global_position)
			if dist_sq < nearest_dist_sq:
				nearest_dist_sq = dist_sq
				nearest = enemy

	return nearest


# --- Shooting ---

func shoot() -> void:
	_can_shoot = false
	shoot_timer.start(fire_rate)

	var bullet_container: Node = get_parent().get_node_or_null("BulletContainer")
	if not bullet_container:
		return

	# Grenade shot (fires occasionally alongside normal bullets)
	if has_grenade and _grenade_cooldown <= 0.0:
		_fire_grenade(bullet_container)
		_grenade_cooldown = fire_rate * 5.0

	# Normal / shotgun bullets
	if bullet_count <= 1:
		_spawn_bullet(bullet_container, rotation)
	else:
		_fire_spread(bullet_container)


func _fire_spread(container: Node) -> void:
	var spread_angle: float = deg_to_rad(30.0)
	var step: float = spread_angle / float(max(bullet_count - 1, 1))
	var start_angle: float = rotation - spread_angle * 0.5

	for i in bullet_count:
		var angle: float = start_angle + step * float(i)
		_spawn_bullet(container, angle)


func _spawn_bullet(container: Node, angle: float) -> void:
	var bullet: Node2D = BulletScene.instantiate()
	var dir := Vector2.RIGHT.rotated(angle)
	var muzzle_offset := dir * 50.0
	bullet.global_position = global_position + muzzle_offset

	container.add_child(bullet)

	if bullet.has_method("setup"):
		bullet.setup(dir, bullet_speed, bullet_damage, bullet_pierce, false)
	else:
		bullet.direction = dir
		bullet.speed = bullet_speed
		bullet.damage = bullet_damage
		bullet.pierce_count = bullet_pierce


func _fire_grenade(container: Node) -> void:
	var grenade: Node2D = BulletScene.instantiate()
	var dir := Vector2.RIGHT.rotated(rotation)
	var muzzle_offset := dir * 50.0
	grenade.global_position = global_position + muzzle_offset

	container.add_child(grenade)

	if grenade.has_method("setup"):
		grenade.setup(dir, bullet_speed * 0.6, bullet_damage * 2, 0, true)
	else:
		grenade.direction = dir
		grenade.is_grenade = true
		grenade.damage = bullet_damage * 2
		grenade.speed = bullet_speed * 0.6


func _on_shoot_timer_timeout() -> void:
	_can_shoot = true


# --- Damage ---

func take_damage(amount: int) -> void:
	health = max(health - amount, 0)
	health_changed.emit(health, max_health)

	if health <= 0:
		died.emit()


# --- Upgrades ---

func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"shotgun":
			bullet_count += 2
		"pierce":
			bullet_pierce += 1
		"grenade":
			has_grenade = true
		"emp_slow":
			slow_factor = max(slow_factor - 0.2, 0.3)
		"fire_rate":
			fire_rate = max(fire_rate - 0.05, 0.1)
		"damage":
			bullet_damage += 10
		"speed":
			bullet_speed += 100.0
		"health":
			max_health += 25
			health = min(health + 25, max_health)
			health_changed.emit(health, max_health)
		"heal":
			health = min(health + 50, max_health)
			health_changed.emit(health, max_health)
		_:
			push_warning("Tower: unknown upgrade_id '%s'" % upgrade_id)
