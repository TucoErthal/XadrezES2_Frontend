extends Camera3D
class_name CameraControls

@export_group("Nodes")
@export var focus_node: Node3D

@export_group("Input Actions")
@export var zoom_in_action: StringName = "camera_zoom_in"
@export var zoom_out_action: StringName = "camera_zoom_out"
@export var orbit_action: StringName = "camera_orbit"
@export var pan_action: StringName = "camera_pan"

@export_group("Camera Settings")
@export var min_distance: float = 2.0
@export var max_distance: float = 50.0
@export_range(0.01, 1.0) var zoom_speed: float = 0.15
@export_range(0.001, 0.05) var orbit_sensitivity: float = 0.005
@export_range(0.001, 0.05) var pan_sensitivity: float = 0.002

@export_group("Smoothing")
@export var zoom_smoothing: float = 10.0
@export var orbit_smoothing: float = 15.0

var _target_distance: float = 10.0
var _target_pitch: float = -PI / 4.0
var _target_yaw: float = 0.0

var _current_distance: float
var _current_pitch: float
var _current_yaw: float

var _focus_point: Vector3 = Vector3.ZERO

func _ready() -> void:
	if focus_node != null:
		focus_node.top_level = true
		focus_node.global_position = Vector3.ZERO
		_focus_point = focus_node.global_position
	else:
		printerr("OrbitCamera: FocusNode is not assigned in the inspector!")
		_focus_point = Vector3.ZERO

	_current_distance = _target_distance
	_current_pitch = _target_pitch
	_current_yaw = _target_yaw

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.is_action_pressed(orbit_action):
			_target_yaw -= event.relative.x * orbit_sensitivity
			_target_pitch -= event.relative.y * orbit_sensitivity
			var pitch_limit: float = deg_to_rad(89.9)
			_target_pitch = clamp(_target_pitch, -pitch_limit, pitch_limit)
		elif Input.is_action_pressed(pan_action):
			var right = global_transform.basis.x
			right.y = 0
			right = right.normalized()

			var forward = -global_transform.basis.z
			forward.y = 0
			
			if forward.length_squared() > 0.001:
				forward = forward.normalized()
			else:
				forward = global_transform.basis.y.normalized()

			var scaled_pan_speed = pan_sensitivity * _current_distance
			_focus_point -= right * event.relative.x * scaled_pan_speed
			_focus_point += forward * event.relative.y * scaled_pan_speed

	elif event.is_action_pressed(zoom_in_action):
		_target_distance -= _target_distance * zoom_speed
		_target_distance = clamp(_target_distance, min_distance, max_distance)
	elif event.is_action_pressed(zoom_out_action):
		_target_distance += _target_distance * zoom_speed
		_target_distance = clamp(_target_distance, min_distance, max_distance)

func _process(delta: float) -> void:
	_current_distance = lerp(_current_distance, _target_distance, zoom_smoothing * delta)
	_current_pitch = lerp(_current_pitch, _target_pitch, orbit_smoothing * delta)
	_current_yaw = lerp_angle(_current_yaw, _target_yaw, orbit_smoothing * delta)

	if focus_node != null:
		focus_node.global_position = _focus_point

	var basis := Basis.from_euler(Vector3(_current_pitch, _current_yaw, 0))
	var offset := basis * Vector3(0, 0, _current_distance)
	
	global_position = _focus_point + offset
	look_at(_focus_point, Vector3.UP)
