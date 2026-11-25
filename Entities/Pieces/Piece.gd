extends Node3D
class_name Piece

static var all_pieces: Array[Piece] = []

var visual_mesh: MeshInstance3D
var board_coordinates: Vector2i = Vector2i.ZERO
var is_white: bool = true
var piece_type: String = ""

var _tinted_material: StandardMaterial3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

@export var theme_path: String = "res://Assets/Marble/" 
@export var height_offset: float = 0.09 # Ajuste no inspetor se precisar subir/descer mais

# Dicionário oficial de notação para evitar conflito entre (K)ing e (K)night
const TYPE_MAP = {
	"pawn": "p",
	"knight": "n",
	"bishop": "b",
	"rook": "r",
	"queen": "q",
	"king": "k"
}

func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			visual_mesh = child
			break

func _enter_tree() -> void:
	all_pieces.append(self)

func _exit_tree() -> void:
	all_pieces.erase(self)

# ==========================================
# CONFIGURAÇÃO DE MODELO E MATERIAL
# ==========================================
func setup_type_label(type: String) -> void:
	piece_type = type.to_lower()
	var color_suffix = "w" if is_white else "b"
	
	# Pega a letra correta baseada no dicionário
	var type_char = TYPE_MAP.get(piece_type, piece_type.substr(0, 1))
	
	var loaded_mesh: Mesh = _load_piece_mesh(type_char, color_suffix)
	
	if loaded_mesh:
		mesh_instance.mesh = loaded_mesh
	else:
		printerr("Erro: Não foi possível carregar a malha para a peça: ", piece_type)
		return

	# 1. ALTURA: Sobe as peças de acordo com o offset
	mesh_instance.position.y = height_offset

	# 2. ROTAÇÃO: Vira as peças pretas 180 graus (eixo Y)
	if not is_white:
		mesh_instance.rotation_degrees.y = 180
	else:
		mesh_instance.rotation_degrees.y = 0
		
	# 3. SOMBRAS: Ativa emissão dupla face
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED

	_apply_material_logic()

func _load_piece_mesh(type_char: String, color_code: String) -> Mesh:
	var extensions = [".res", ".glb", ".tres", ".obj"]
	var candidate_names = [
		type_char + color_code,     # Ex: pw, nb
		type_char + "1" + color_code, # Ex: p1w, n1b
		type_char                   # Ex: p, n
	]
	
	for name_variant in candidate_names:
		for ext in extensions:
			var full_path = theme_path.path_join(name_variant + ext)
			if ResourceLoader.exists(full_path):
				var res = load(full_path)
				if res is Mesh:
					return res
				elif res is PackedScene:
					var inst = res.instantiate()
					var mesh_child = _find_mesh_instance_in_node(inst)
					if mesh_child and mesh_child.mesh:
						var mesh_found = mesh_child.mesh
						inst.free()
						return mesh_found
					inst.free()
	return null

func _apply_material_logic() -> void:
	if not mesh_instance.mesh: return
	
	var surface_count = mesh_instance.mesh.get_surface_count()
	
	# Faz um loop por TODAS as superfícies da malha (corrige cull back em modelos complexos)
	for i in range(surface_count):
		mesh_instance.set_surface_override_material(i, null)
		var existing_mat = _get_active_material(i)
		
		var mat_to_use: Material
		if existing_mat:
			mat_to_use = existing_mat.duplicate()
		else:
			mat_to_use = StandardMaterial3D.new()
			mat_to_use.albedo_color = Color(0.9, 0.9, 0.85) if is_white else Color(0.15, 0.15, 0.15)
			mat_to_use.roughness = 0.3

		if mat_to_use is BaseMaterial3D:
			mat_to_use.cull_mode = BaseMaterial3D.CULL_DISABLED 
			mat_to_use.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat_to_use.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY

		mesh_instance.set_surface_override_material(i, mat_to_use)

func _get_active_material(surface_idx: int) -> Material:
	var mat = mesh_instance.get_surface_override_material(surface_idx)
	if mat:
		return mat
	if mesh_instance.mesh and mesh_instance.mesh.get_surface_count() > surface_idx:
		return mesh_instance.mesh.surface_get_material(surface_idx)
	return null

func _find_mesh_instance_in_node(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance_in_node(child)
		if found:
			return found
	return null

# ==========================================
# SELEÇÃO DE PEÇAS
# ==========================================
func select() -> void:
	if visual_mesh == null or not visual_mesh.mesh: return
	
	if _tinted_material == null:
		var active_mat = _get_active_material(0)
		if active_mat:
			_tinted_material = active_mat.duplicate()
		else:
			_tinted_material = StandardMaterial3D.new()
			
		if _tinted_material is BaseMaterial3D:
			_tinted_material.albedo_color = Color(1.0, 0.2, 0.2)
			_tinted_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			_tinted_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	visual_mesh.material_override = _tinted_material

func deselect() -> void:
	if visual_mesh != null:
		visual_mesh.material_override = null
