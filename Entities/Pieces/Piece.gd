extends Node3D
class_name Piece

static var all_pieces: Array[Piece] = []

var visual_mesh: MeshInstance3D
var board_coordinates: Vector2i = Vector2i.ZERO
var is_white: bool = true
var piece_type: String = ""

var _tinted_material: StandardMaterial3D
var _type_label: Label3D

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
		
func setup_type_label(type: String) -> void:
	piece_type = type
	
	if _type_label == null:
		_type_label = Label3D.new()
		# Posiciona um pouco acima da caixa da peça (que tem altura 1.0)
		_type_label.position = Vector3(0, 1.25, 0)
		# Faz o texto sempre ficar de frente para a câmera de qualquer ângulo
		_type_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_type_label.font_size = 48
		_type_label.outline_size = 10
		add_child(_type_label)
	
	_type_label.text = type
	
	# Ajusta as cores do texto e do contorno para garantir bom contraste
	if is_white:
		_type_label.modulate = Color.BLACK
		_type_label.outline_modulate = Color.WHITE
	else:
		_type_label.modulate = Color.WHITE
		_type_label.outline_modulate = Color.BLACK
