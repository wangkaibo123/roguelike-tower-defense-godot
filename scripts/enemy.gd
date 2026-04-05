extends Node2D

signal died(points: int)
signal reached_tower(damage: int)

# Enemy configuration
var enemy_type: String = "triangle"
var speed: float = 120.0
var max_health: float = 50.0
var health: float = 50.0
var size: float = 15.0
var color: Color = Color("#E85D75")
var points: int = 10
var damage: int = 10

# Movement and state
var target_position: Vector2 = Vector2.ZERO
var slow_multiplier: float = 1.0
var is_alive: bool = true
var _rotation_angle: float = 0.0

func _ready() -> void:
	# Create Area2D child for collision detection
	var area := Area2D.new()
	area.name = "HitArea"
	area.collision_layer = 4  # layer 3 (bitmask 4) = enemies
	area.collision_mask = 2   # detect layer 2 = bullets
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = size
	collision.shape = shape
	area.add_child(collision)
	add_child(area)


func setup(type: String, target: Vector2, slow_mult: float = 1.0) -> void:
	enemy_type = type
	target_position = target
	slow_multiplier = slow_mult

	match type:
		"triangle":
			speed = 120.0
			max_health = 50.0
			size = 15.0
			color = Color("#E85D75")
			points = 10
			damage = 10
		"square":
			speed = 60.0
			max_health = 150.0
			size = 18.0
			color = Color("#9B59B6")
			points = 25
			damage = 20
		"diamond":
			speed = 90.0
			max_health = 100.0
			size = 16.0
			color = Color("#E67E22")
			points = 15
			damage = 15

	health = max_health

	# Update collision shape to match size
	var hit_area := get_node("HitArea") as Area2D
	if hit_area:
		var col_shape := hit_area.get_child(0) as CollisionShape2D
		if col_shape and col_shape.shape is CircleShape2D:
			(col_shape.shape as CircleShape2D).radius = size


func _process(delta: float) -> void:
	if not is_alive:
		return

	# Rotate for visual flair
	_rotation_angle += delta * 1.5

	# Move toward target
	var direction := (target_position - global_position).normalized()
	var effective_speed := speed * slow_multiplier
	global_position += direction * effective_speed * delta

	# Check if reached tower (within ~35px)
	if global_position.distance_to(target_position) < 35.0:
		is_alive = false
		reached_tower.emit(damage)
		queue_free()
		return

	queue_redraw()


func _draw() -> void:
	match enemy_type:
		"triangle":
			_draw_triangle()
		"square":
			_draw_square()
		"diamond":
			_draw_diamond()

	# Health bar (only if damaged)
	if health < max_health:
		var bar_width := size * 2.0
		var bar_height := 3.0
		var bar_y := -size - 8.0
		var bg_rect := Rect2(-bar_width / 2.0, bar_y, bar_width, bar_height)
		draw_rect(bg_rect, Color(0.2, 0.2, 0.2, 0.8))
		var health_ratio := clampf(health / max_health, 0.0, 1.0)
		var fg_rect := Rect2(-bar_width / 2.0, bar_y, bar_width * health_ratio, bar_height)
		draw_rect(fg_rect, Color(0.2, 0.9, 0.2, 0.9))


func _draw_triangle() -> void:
	var pts: PackedVector2Array = []
	for i in 3:
		var angle := _rotation_angle + (TAU / 3.0) * i - PI / 2.0
		pts.append(Vector2(cos(angle), sin(angle)) * size)
	draw_colored_polygon(pts, color)
	# White outline
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color.WHITE, 1.5, true)


func _draw_square() -> void:
	var pts: PackedVector2Array = []
	for i in 4:
		var angle := _rotation_angle + (TAU / 4.0) * i + PI / 4.0
		pts.append(Vector2(cos(angle), sin(angle)) * size)
	draw_colored_polygon(pts, color)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color.WHITE, 1.5, true)


func _draw_diamond() -> void:
	var stretch_x := size * 0.7
	var stretch_y := size * 1.2
	var pts: PackedVector2Array = [
		Vector2(0, -stretch_y).rotated(_rotation_angle * 0.5),
		Vector2(stretch_x, 0).rotated(_rotation_angle * 0.5),
		Vector2(0, stretch_y).rotated(_rotation_angle * 0.5),
		Vector2(-stretch_x, 0).rotated(_rotation_angle * 0.5),
	]
	draw_colored_polygon(pts, color)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color.WHITE, 1.5, true)


func take_damage(amount: float) -> void:
	if not is_alive:
		return

	health -= amount
	show_damage_number(amount)

	if health <= 0.0:
		health = 0.0
		die()


func show_damage_number(amount: float) -> void:
	var label := Label.new()
	label.text = str(int(amount))
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-16, -size - 20)
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


func die() -> void:
	if not is_alive:
		return
	is_alive = false

	died.emit(points)

	# Flash white death effect
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.05)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)

	# Spawn particle-like fragments
	_spawn_death_particles()

	tween.tween_callback(queue_free)


func _spawn_death_particles() -> void:
	var particle_count := 6
	for i in particle_count:
		var p := Node2D.new()
		p.position = Vector2.ZERO
		# Store particle data via meta
		var angle := (TAU / particle_count) * i + randf() * 0.5
		var vel := Vector2(cos(angle), sin(angle)) * randf_range(40.0, 90.0)
		var p_size := randf_range(2.0, 5.0)
		var p_color := color.lightened(0.3)

		add_child(p)

		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", vel * 0.6, 0.4).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, 0.4)
		tw.set_parallel(false)
		tw.tween_callback(p.queue_free)
