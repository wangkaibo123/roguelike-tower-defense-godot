extends Node2D
## Draws floating geometric shapes in the background for visual flair.
## Matches the dark crimson aesthetic with subtle triangle/square outlines drifting.

const SCREEN_SIZE := Vector2(480, 854)
const NUM_PARTICLES := 25
const COLOR_DIM := Color(1.0, 1.0, 1.0, 0.06)

var _particles: Array[Dictionary] = []


func _ready() -> void:
	z_index = -5
	for i in NUM_PARTICLES:
		_particles.append(_make_particle())


func _process(delta: float) -> void:
	for p in _particles:
		p["pos"] += p["vel"] * delta
		p["rot"] += p["rot_speed"] * delta

		# Wrap around screen
		if p["pos"].x < -30:
			p["pos"].x = SCREEN_SIZE.x + 30
		elif p["pos"].x > SCREEN_SIZE.x + 30:
			p["pos"].x = -30
		if p["pos"].y < -30:
			p["pos"].y = SCREEN_SIZE.y + 30
		elif p["pos"].y > SCREEN_SIZE.y + 30:
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

		# Close the outline
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, col, 1.0, true)


func _make_particle() -> Dictionary:
	var sides := [3, 4, 4, 3, 3][randi() % 5]
	return {
		"pos": Vector2(randf_range(0, SCREEN_SIZE.x), randf_range(0, SCREEN_SIZE.y)),
		"vel": Vector2(randf_range(-12, 12), randf_range(-8, 8)),
		"rot": randf() * TAU,
		"rot_speed": randf_range(-0.5, 0.5),
		"size": randf_range(6, 18),
		"sides": sides,
		"color": Color_DIM_variant(),
	}


func Color_DIM_variant() -> Color:
	var alpha := randf_range(0.03, 0.09)
	return Color(1.0, randf_range(0.8, 1.0), randf_range(0.8, 1.0), alpha)
