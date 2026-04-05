extends Node2D
## Draws floating geometric shapes in the background for visual flair.
## Adapts to viewport size dynamically.

const NUM_PARTICLES := 25

var _particles: Array[Dictionary] = []


func _get_screen() -> Vector2:
	return get_viewport_rect().size


func _ready() -> void:
	z_index = -5
	for i in NUM_PARTICLES:
		_particles.append(_make_particle())


func _process(delta: float) -> void:
	var scr := _get_screen()
	for p in _particles:
		p["pos"] += p["vel"] * delta
		p["rot"] += p["rot_speed"] * delta

		if p["pos"].x < -30:
			p["pos"].x = scr.x + 30
		elif p["pos"].x > scr.x + 30:
			p["pos"].x = -30
		if p["pos"].y < -30:
			p["pos"].y = scr.y + 30
		elif p["pos"].y > scr.y + 30:
			p["pos"].y = -30

	queue_redraw()


func _draw() -> void:
	for p in _particles:
		var pos: Vector2 = p["pos"]
		var sz: float = p["size"]
		var rot: float = p["rot"]
		var sides: int = p["sides"]
		var col: Color = p["color"]

		var pts: PackedVector2Array = []
		for i in sides:
			var angle: float = rot + (TAU / sides) * i
			pts.append(pos + Vector2(cos(angle), sin(angle)) * sz)

		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, col, 1.0, true)


func _make_particle() -> Dictionary:
	var scr := _get_screen()
	var side_options: Array[int] = [3, 4, 4, 3, 3]
	var sides: int = side_options[randi() % side_options.size()]
	return {
		"pos": Vector2(randf_range(0, scr.x), randf_range(0, scr.y)),
		"vel": Vector2(randf_range(-12, 12), randf_range(-8, 8)),
		"rot": randf() * TAU,
		"rot_speed": randf_range(-0.5, 0.5),
		"size": randf_range(6, 18),
		"sides": sides,
		"color": _dim_variant(),
	}


func _dim_variant() -> Color:
	var alpha := randf_range(0.03, 0.09)
	return Color(1.0, randf_range(0.8, 1.0), randf_range(0.8, 1.0), alpha)
