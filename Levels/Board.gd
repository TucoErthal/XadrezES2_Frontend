extends MeshInstance3D
class_name Board

static var instance: Board

func _ready() -> void:
	if instance == null:
		instance = self
	elif instance != self:
		queue_free()

func get_position_in_board(coordinates: Vector2) -> Variant:
	if coordinates.x < 0 or coordinates.x > 7 or coordinates.y < 0 or coordinates.y > 7:
		printerr("Coordenadas fora do tabuleiro!")
		return null
	
	var longest_axis: float = mesh.get_aabb().get_longest_axis_size() if mesh else 8.0
	var half_board: float = longest_axis / 2.0
	var half_tile: float = longest_axis / 16.0

	var local_position := Vector3(
		coordinates.x - half_board + half_tile,
		0,
		coordinates.y - half_board + half_tile
	)

	return to_global(local_position)

func get_coordinates_from_position(target_position: Vector3) -> Vector2i:
	var local_position := to_local(target_position)
	
	var longest_axis: float = mesh.get_aabb().get_longest_axis_size() if mesh else 8.0
	var half_board: float = longest_axis / 2.0
	var half_tile: float = longest_axis / 16.0

	var x: int = roundi(local_position.x + half_board - half_tile)
	var y: int = roundi(local_position.z + half_board - half_tile)

	return Vector2i(x, y)
