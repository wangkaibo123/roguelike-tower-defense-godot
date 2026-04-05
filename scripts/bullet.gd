extends Node2D

# -- Properties --
@export var speed: float = 600.0
@export var damage: float = 25.0
var direction: Vector2 = Vector2.RIGHT
var pierce_count: int = 0
var is_grenade: bool = false
var grenade_radius: float = 80.0
var lifetime: float = 2.0
var enemies_hit: Array = []

# Trail tracking
var _trail_positions: Array[Vector2] = []
const MAX_TRAIL_LENGTH: int = 6

# Grenade pulse
var _grenade_pulse_time: float = 0.0

# Explosion state
var _exploding: bool = false
var _explosion_progress: float = 0.0
const EXPLOSION_DURATION: float = 0.25

## ------------------------------------------------------------------ _ready
func _ready() -> void:
	# Configure the Area2D child for collision.
	var area := $Area2D as Area2D
	area.collision_layer = 2   # layer 2 = bullets
	area.collision_mask  = 4   # detect layer 3 = enemies (bitmask value 4)
	area.area_entered.connect(_on_area_entered)

	# Start a one-shot lifetime timer so the bullet auto-frees.
	var timer := Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

	# Seed the trail with the current position.
	_trail_positions.push_back(global_position)


## ------------------------------------------------------------------ setup
func setup(dir: Vector2, spd: float, dmg: float, pierce: int = 0, grenade: bool = false) -> void:
	direction   = dir.normalized()
	speed       = spd
	damage      = dmg
	pierce_count = pierce
	is_grenade  = grenade
	rotation    = direction.angle()


## ---------------------------------------------------------------- _process
func _process(delta: float) -> void:
	# While exploding, only advance the explosion animation.
	if _exploding:
		_explosion_progress += delta / EXPLOSION_DURATION
		queue_redraw()
		if _explosion_progress >= 1.0:
			queue_free()
		return

	# Normal movement.
	global_position += direction * speed * delta

	# Grenade pulse timer (for the draw pulsing effect).
	if is_grenade:
		_grenade_pulse_time += delta * 6.0

	# Update trail history.
	_trail_positions.push_back(global_position)
	if _trail_positions.size() > MAX_TRAIL_LENGTH:
		_trail_positions.pop_front()

	queue_redraw()
	check_bounds()


## ------------------------------------------------------------------ _draw
func _draw() -> void:
	if _exploding:
		_draw_explosion()
		return

	if is_grenade:
		_draw_grenade()
	else:
		_draw_normal()


func _draw_normal() -> void:
	# Draw a short trail fading from transparent to yellow.
	if _trail_positions.size() >= 2:
		for i in range(_trail_positions.size() - 1):
			var t: float = float(i) / float(_trail_positions.size() - 1)
			var col := Color(1.0, 1.0, 0.6, t * 0.6)
			var width: float = lerpf(1.0, 3.0, t)
			var from: Vector2 = _trail_positions[i] - global_position
			var to: Vector2   = _trail_positions[i + 1] - global_position
			draw_line(from, to, col, width)

	# Bright core.
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 1.0, 0.85))
	# Outer glow.
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.95, 0.3, 0.35))


func _draw_grenade() -> void:
	# Pulsing radius effect.
	var pulse: float = 1.0 + sin(_grenade_pulse_time) * 0.15
	var radius: float = 7.0 * pulse

	# Outer glow.
	draw_circle(Vector2.ZERO, radius + 3.0, Color(1.0, 0.45, 0.0, 0.25))
	# Main body.
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.55, 0.1))
	# Bright center highlight.
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1.0, 0.85, 0.4))


func _draw_explosion() -> void:
	var t: float = clampf(_explosion_progress, 0.0, 1.0)
	var current_radius: float = grenade_radius * t
	var alpha: float = 1.0 - t
	# Expanding shockwave ring.
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 48, Color(1.0, 0.6, 0.1, alpha), 3.0)
	# Filled flash.
	draw_circle(Vector2.ZERO, current_radius * 0.7, Color(1.0, 0.8, 0.2, alpha * 0.3))


## ------------------------------------------------------- _on_area_entered
func _on_area_entered(area: Area2D) -> void:
	if _exploding:
		return

	# Ensure the area belongs to an enemy node.
	var enemy := area.get_parent()
	if enemy == null:
		return

	# Skip enemies already pierced by this bullet.
	if enemies_hit.has(enemy):
		return

	# Deal direct damage.
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
	enemies_hit.append(enemy)

	# Grenade: AOE then explode visually.
	if is_grenade:
		_deal_grenade_aoe()
		_start_explosion()
		return

	# Pierce logic.
	if pierce_count > 0:
		pierce_count -= 1
		# Bullet keeps going.
	else:
		queue_free()


## ------------------------------------------------------- _deal_grenade_aoe
func _deal_grenade_aoe() -> void:
	# Find all enemy bodies/areas within the grenade radius.
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = grenade_radius
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 4  # layer 3 = enemies
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results := space_state.intersect_shape(query, 64)
	for result in results:
		var collider = result["collider"]
		var enemy = collider.get_parent() if collider is Area2D else collider
		if enemy != null and not enemies_hit.has(enemy):
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
			enemies_hit.append(enemy)


## ------------------------------------------------------ _start_explosion
func _start_explosion() -> void:
	_exploding = true
	_explosion_progress = 0.0
	# Stop movement by zeroing speed.
	speed = 0.0
	# Disable further collision.
	var area := $Area2D as Area2D
	area.set_deferred("monitoring", false)


## --------------------------------------------------------- check_bounds
func check_bounds() -> void:
	var vp_rect := get_viewport_rect()
	# Add a small margin so bullets aren't freed the instant they touch the edge.
	var margin: float = 32.0
	var expanded := vp_rect.grow(margin)
	if not expanded.has_point(global_position):
		queue_free()
