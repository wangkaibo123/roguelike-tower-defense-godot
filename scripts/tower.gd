extends Node2D
## Central tower that auto-aims and fires at the nearest enemy.
## Draws weapon-specific range indicators.

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

# Range properties
var base_range: float = 250.0
var attack_range: float = 250.0  # current effective range

# Internal state
var _target: Node2D = null
var _can_shoot: bool = true
var _grenade_cooldown: float = 0.0
var _time: float = 0.0  # for animation

@onready var shoot_timer: Timer = Timer.new()

# --- Range indicator colors ---
const RANGE_BASE_COLOR := Color(1.0, 1.0, 1.0, 0.08)
const RANGE_SHOTGUN_COLOR := Color(1.0, 0.84, 0.0, 0.1)
const RANGE_GRENADE_COLOR := Color(1.0, 0.45, 0.0, 0.1)
const RANGE_PIERCE_COLOR := Color(0.6, 0.3, 1.0, 0.12)
const RANGE_EMP_COLOR := Color(0.35, 0.7, 1.0, 0.08)
const GRENADE_AOE_RADIUS := 80.0

# --- Lifecycle ---

func _ready() -> void:
	health = max_health
	attack_range = base_range

	shoot_timer.name = "ShootTimer"
	shoot_timer.wait_time = fire_rate
	shoot_timer.one_shot = true
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	add_child(shoot_timer)


func _process(delta: float) -> void:
	_time += delta
	_target = find_nearest_enemy()

	if _target and is_instance_valid(_target):
		var direction: float = global_position.direction_to(_target.global_position).angle()
		rotation = lerp_angle(rotation, direction, rotation_speed * delta)

		if _can_shoot:
			shoot()

	if has_grenade and _grenade_cooldown > 0.0:
		_grenade_cooldown -= delta

	# Recalculate effective range
	_update_range()

	queue_redraw()


func _update_range() -> void:
	attack_range = base_range
	# Pierce extends effective range
	if bullet_pierce > 0:
		attack_range += bullet_pierce * 40.0
	# Faster bullets = longer effective range
	attack_range *= (bullet_speed / 600.0)
	attack_range = clampf(attack_range, 150.0, 600.0)


# --- Drawing ---

func _draw() -> void:
	# Draw range indicators FIRST (behind tower)
	_draw_range_indicators()

	# --- Tower body ---
	draw_circle(Vector2.ZERO, 33.0, Color(0.3, 0.3, 0.3))
	draw_circle(Vector2.ZERO, 30.0, Color("#2A2A2A"))
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 48, Color(0.25, 0.25, 0.25), 1.5)

	# --- Cannon barrel ---
	var barrel_length: float = 38.0
	var barrel_width: float = 10.0
	var barrel_offset: float = 12.0
	var barrel_rect := Rect2(
		Vector2(barrel_offset, -barrel_width * 0.5),
		Vector2(barrel_length, barrel_width)
	)
	draw_rect(barrel_rect, Color(0.22, 0.22, 0.22))
	draw_rect(barrel_rect, Color(0.35, 0.35, 0.35), false, 1.5)

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


func _draw_range_indicators() -> void:
	# We draw in local space (tower is at 0,0), but range circles don't rotate
	# with the tower. Use inverse rotation to cancel tower rotation.
	var inv_rot: float = -rotation

	# === 1. EMP / Slow aura (innermost, drawn if slow_factor < 1.0) ===
	if slow_factor < 1.0:
		_draw_emp_aura(inv_rot)

	# === 2. Base range circle (always shown) ===
	_draw_base_range(inv_rot)

	# === 3. Shotgun fan overlay ===
	if bullet_count > 1:
		_draw_shotgun_cone()

	# === 4. Grenade AOE indicator ===
	if has_grenade:
		_draw_grenade_range(inv_rot)

	# === 5. Pierce extended range ===
	if bullet_pierce > 0:
		_draw_pierce_range(inv_rot)


func _draw_base_range(inv_rot: float) -> void:
	# Subtle dashed circle with slow pulse
	var pulse: float = 1.0 + sin(_time * 1.5) * 0.03
	var r: float = attack_range * pulse

	# Outer ring
	var seg_count: int = 48
	var dash_on: int = 3  # segments on
	var dash_off: int = 2 # segments off
	var cycle: int = dash_on + dash_off

	for i in seg_count:
		if (i % cycle) >= dash_on:
			continue
		var a0: float = inv_rot + (TAU / seg_count) * i
		var a1: float = inv_rot + (TAU / seg_count) * (i + 1)
		var p0 := Vector2(cos(a0), sin(a0)) * r
		var p1 := Vector2(cos(a1), sin(a1)) * r
		draw_line(p0, p1, RANGE_BASE_COLOR, 1.5, true)

	# Very subtle filled circle
	draw_circle(Vector2.ZERO, r, Color(1.0, 1.0, 1.0, 0.015))


func _draw_shotgun_cone() -> void:
	# Fan/cone showing spread direction (rotates WITH the tower)
	var spread_half: float = deg_to_rad(15.0) * bullet_count * 0.5
	var fan_radius: float = attack_range * 0.9

	# Filled fan
	var fan_pts: PackedVector2Array = [Vector2.ZERO]
	var fan_segs: int = 16
	for i in range(fan_segs + 1):
		var t: float = float(i) / float(fan_segs)
		var a: float = -spread_half + spread_half * 2.0 * t
		fan_pts.append(Vector2(cos(a), sin(a)) * fan_radius)

	var fan_color := RANGE_SHOTGUN_COLOR
	# Animate alpha subtly
	fan_color.a *= (0.8 + sin(_time * 2.0) * 0.2)
	draw_colored_polygon(fan_pts, fan_color)

	# Fan edge lines
	var edge_color := Color(1.0, 0.84, 0.0, 0.2)
	var left_edge := Vector2(cos(-spread_half), sin(-spread_half)) * fan_radius
	var right_edge := Vector2(cos(spread_half), sin(spread_half)) * fan_radius
	draw_line(Vector2.ZERO, left_edge, edge_color, 1.0, true)
	draw_line(Vector2.ZERO, right_edge, edge_color, 1.0, true)

	# Arc at fan edge
	draw_arc(Vector2.ZERO, fan_radius, -spread_half, spread_half, fan_segs, edge_color, 1.0, true)

	# Spread line markers inside the fan
	var total_lines: int = bullet_count
	if total_lines > 1:
		var step_a: float = (spread_half * 2.0) / float(total_lines - 1)
		for i in total_lines:
			var a: float = -spread_half + step_a * float(i)
			var line_end := Vector2(cos(a), sin(a)) * fan_radius * 0.7
			draw_line(Vector2.ZERO, line_end, Color(1.0, 0.84, 0.0, 0.12), 1.0, true)


func _draw_grenade_range(inv_rot: float) -> void:
	# Outer range ring for grenade (slightly beyond normal range due to slower speed)
	var grenade_range: float = attack_range * 0.7
	var pulse: float = 1.0 + sin(_time * 3.0) * 0.05

	# Pulsing AOE preview circles at cardinal directions on the range ring
	var aoe_r: float = GRENADE_AOE_RADIUS * pulse
	var marker_count: int = 4
	for i in marker_count:
		var a: float = inv_rot + (TAU / marker_count) * i + _time * 0.3
		var center_pt := Vector2(cos(a), sin(a)) * grenade_range

		# AOE circle
		draw_arc(center_pt, aoe_r, 0.0, TAU, 24, Color(1.0, 0.45, 0.0, 0.08 * pulse), 1.0, true)

		# Explosion cross marker at center
		var mk: float = 5.0
		draw_line(center_pt - Vector2(mk, 0), center_pt + Vector2(mk, 0), Color(1.0, 0.5, 0.1, 0.15), 1.5, true)
		draw_line(center_pt - Vector2(0, mk), center_pt + Vector2(0, mk), Color(1.0, 0.5, 0.1, 0.15), 1.5, true)

	# Grenade range ring (dotted, orange)
	var seg_count: int = 36
	for i in seg_count:
		if i % 3 == 2:
			continue
		var a0: float = inv_rot + (TAU / seg_count) * i
		var a1: float = inv_rot + (TAU / seg_count) * (i + 1)
		var p0 := Vector2(cos(a0), sin(a0)) * grenade_range
		var p1 := Vector2(cos(a1), sin(a1)) * grenade_range
		draw_line(p0, p1, Color(1.0, 0.5, 0.15, 0.15), 1.5, true)


func _draw_pierce_range(inv_rot: float) -> void:
	# Extended range ring with arrow tick marks
	var extra: float = bullet_pierce * 40.0
	var pierce_range: float = attack_range
	var inner_range: float = attack_range - extra

	# Outer dashed ring (purple)
	var seg_count: int = 36
	for i in seg_count:
		if i % 2 == 1:
			continue
		var a0: float = inv_rot + (TAU / seg_count) * i
		var a1: float = inv_rot + (TAU / seg_count) * (i + 1)
		var p0 := Vector2(cos(a0), sin(a0)) * pierce_range
		var p1 := Vector2(cos(a1), sin(a1)) * pierce_range
		draw_line(p0, p1, RANGE_PIERCE_COLOR, 2.0, true)

	# Arrow tick marks pointing outward between inner and outer ring
	var tick_count: int = 8
	for i in tick_count:
		var a: float = inv_rot + (TAU / tick_count) * i + _time * 0.5
		var dir_v := Vector2(cos(a), sin(a))
		var p_inner := dir_v * inner_range
		var p_outer := dir_v * pierce_range

		# Main line
		draw_line(p_inner, p_outer, Color(0.6, 0.3, 1.0, 0.18), 1.5, true)

		# Arrowhead
		var tip := p_outer
		var arrow_sz: float = 8.0
		var left := tip - dir_v * arrow_sz + dir_v.rotated(PI * 0.5) * arrow_sz * 0.4
		var right := tip - dir_v * arrow_sz - dir_v.rotated(PI * 0.5) * arrow_sz * 0.4
		draw_line(tip, left, Color(0.6, 0.3, 1.0, 0.2), 1.5, true)
		draw_line(tip, right, Color(0.6, 0.3, 1.0, 0.2), 1.5, true)

	# Fill between rings
	# Draw subtle radial gradient approximation using concentric arcs
	var ring_steps: int = 4
	for s in ring_steps:
		var t: float = float(s) / float(ring_steps)
		var r: float = lerpf(inner_range, pierce_range, t)
		var alpha: float = lerpf(0.0, 0.04, t)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(0.6, 0.3, 1.0, alpha), 1.0, true)


func _draw_emp_aura(inv_rot: float) -> void:
	# Soft pulsing blue aura ring showing slow effect area
	var slow_strength: float = 1.0 - slow_factor  # 0.0 to 0.7
	var aura_radius: float = attack_range * (0.5 + slow_strength * 0.3)
	var pulse: float = sin(_time * 2.5) * 0.5 + 0.5

	# Multiple concentric rings for glow effect
	var rings: int = 3
	for r_i in rings:
		var t: float = float(r_i) / float(rings)
		var r: float = aura_radius * (0.85 + t * 0.15)
		var alpha: float = (0.06 + slow_strength * 0.08) * (1.0 - t * 0.5) * (0.7 + pulse * 0.3)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.35, 0.7, 1.0, alpha), 1.5 - t * 0.5, true)

	# Inner filled glow
	draw_circle(Vector2.ZERO, aura_radius * 0.85, Color(0.3, 0.6, 1.0, 0.02 * (0.5 + pulse * 0.5)))

	# Slow icon markers rotating around the aura
	var icon_count: int = 3
	for i in icon_count:
		var a: float = inv_rot + (TAU / icon_count) * i + _time * 0.8
		var pos := Vector2(cos(a), sin(a)) * aura_radius * 0.9
		# Snowflake-like cross
		var mk: float = 4.0
		var ic_color := Color(0.4, 0.8, 1.0, 0.15 + pulse * 0.1)
		draw_line(pos - Vector2(mk, 0), pos + Vector2(mk, 0), ic_color, 1.5, true)
		draw_line(pos - Vector2(0, mk), pos + Vector2(0, mk), ic_color, 1.5, true)
		draw_line(pos - Vector2(mk, mk) * 0.7, pos + Vector2(mk, mk) * 0.7, ic_color, 1.0, true)
		draw_line(pos - Vector2(-mk, mk) * 0.7, pos + Vector2(-mk, mk) * 0.7, ic_color, 1.0, true)


# --- Enemy Detection ---

func find_nearest_enemy() -> Node2D:
	var enemy_container: Node = get_parent().get_node_or_null("EnemyContainer")
	if not enemy_container:
		return null

	var nearest: Node2D = null
	var nearest_dist_sq: float = INF
	var range_sq: float = attack_range * attack_range

	for enemy in enemy_container.get_children():
		if not is_instance_valid(enemy):
			continue
		if enemy is Node2D:
			var dist_sq: float = global_position.distance_squared_to(enemy.global_position)
			if dist_sq < nearest_dist_sq and dist_sq <= range_sq:
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

	if has_grenade and _grenade_cooldown <= 0.0:
		_fire_grenade(bullet_container)
		_grenade_cooldown = fire_rate * 5.0

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
