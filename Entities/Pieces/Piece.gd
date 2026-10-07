extends Node3D
class_name Piece

static var all_pieces: Array[Piece] = []

var visual_mesh: MeshInstance3D
var board_coordinates: Vector2i = Vector2i.ZERO
var is_white: bool = true

var _tinted_material: StandardMaterial3D

func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			visual_mesh = child
			break

func _enter_tree() -> void:
	all_pieces.append(self)

func _exit_tree() -> void:
	all_pieces.erase(self)

func select() -> void:
	if visual_mesh == null:
		return

	if _tinted_material == null:
		var original_mat = visual_mesh.get_active_material(0)
		if original_mat is StandardMaterial3D:
			_tinted_material = original_mat.duplicate()
			_tinted_material.albedo_color = Color.RED

	if _tinted_material != null:
		visual_mesh.material_override = _tinted_material

func deselect() -> void:
	if visual_mesh != null:
		visual_mesh.material_override = null
