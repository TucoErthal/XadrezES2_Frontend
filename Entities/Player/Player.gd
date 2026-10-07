extends Node
class_name Player

@export var select_action: StringName = "select"

var selected_piece: Piece

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(select_action):
		_try_select_piece()
		get_viewport().set_input_as_handled()

func _try_select_piece() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	var ray_length: float = 1000.0
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_normal: Vector3 = camera.project_ray_normal(mouse_pos)
	var ray_end: Vector3 = ray_origin + ray_normal * ray_length

	var closest_piece: Piece = null
	var closest_distance: float = INF

	# Verifica qual peça foi clicada
	for piece in Piece.all_pieces:
		var visual_mesh: MeshInstance3D = piece.visual_mesh
		
		if visual_mesh == null or visual_mesh.mesh == null:
			continue

		var inverse_transform: Transform3D = visual_mesh.global_transform.affine_inverse()
		var local_ray_origin: Vector3 = inverse_transform * ray_origin
		var local_ray_end: Vector3 = inverse_transform * ray_end

		var bounds: AABB = visual_mesh.mesh.get_aabb()
		var hit = bounds.intersects_segment(local_ray_origin, local_ray_end)

		if hit != null:
			var distance_sq: float = ray_origin.distance_squared_to(piece.global_position)
			if distance_sq < closest_distance:
				closest_distance = distance_sq
				closest_piece = piece

	# Se clicou em uma peça
	if closest_piece != null:
		var my_side = RestClient.my_side
		var is_my_piece = (closest_piece.is_white and my_side == "WHITE") or (not closest_piece.is_white and my_side == "BLACK")
		
		if not is_my_piece:
			print("Você só pode selecionar suas próprias peças!")
			return
		
		_clear_selections()

		selected_piece = closest_piece
		selected_piece.select()
		
		print("SUCCESS! Selected Piece at ", selected_piece.board_coordinates)
	else:
		# Se clicou no tabuleiro vazio enquanto tinha uma peça selecionada
		if selected_piece != null and Board.instance != null:
			var board_plane := Plane(Board.instance.global_transform.basis.y, Board.instance.global_position)
			var intersection = board_plane.intersects_ray(ray_origin, ray_normal)

			if intersection != null:
				var board_coords: Vector2i = Board.instance.get_coordinates_from_position(intersection)

				if board_coords.x >= 0 and board_coords.x <= 7 and board_coords.y >= 0 and board_coords.y <= 7:
					var snap_position = Board.instance.get_position_in_board(board_coords)
					if snap_position != null:
						selected_piece.global_position = snap_position
						selected_piece.board_coordinates = board_coords
						print("Piece moved to ", board_coords)

		selected_piece = null
		_clear_selections()
		print("Selection cleared.")

func _clear_selections() -> void:
	for piece in Piece.all_pieces:
		piece.deselect()
