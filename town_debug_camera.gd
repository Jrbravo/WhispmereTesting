extends Camera3D

## Temporary layout-review camera. F8 toggles this camera and the player camera.
@export var enabled_for_preview: bool = false
@export var move_speed: float = 24.0
@export var look_sensitivity: float = 0.0025
var _yaw: float = 0.0
var _pitch: float = -0.78
var _active: bool = false
var _player_camera: Camera3D

func _ready() -> void:
	_player_camera = get_tree().current_scene.get_node_or_null("Player/CameraPivot/SpringArm3D/Camera3D") as Camera3D
	global_position = Vector3(0.0, 105.0, 95.0)
	_yaw = 0.0
	_pitch = -0.72
	rotation = Vector3(_pitch, _yaw, 0.0)
	look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	_yaw = rotation.y
	_pitch = rotation.x
	if enabled_for_preview:
		activate()

func activate() -> void:
	_active = true
	make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		if _active:
			_active = false
			if is_instance_valid(_player_camera):
				_player_camera.make_current()
		else:
			activate()
		get_viewport().set_input_as_handled()
	elif _active and event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if button.pressed else Input.MOUSE_MODE_VISIBLE
	elif _active and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		_yaw -= motion.relative.x * look_sensitivity
		_pitch = clampf(_pitch - motion.relative.y * look_sensitivity, -1.5, 0.1)
		rotation = Vector3(_pitch, _yaw, 0.0)

func _process(delta: float) -> void:
	if not _active:
		return
	var direction: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		direction -= global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		direction += global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		direction -= global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		direction += global_transform.basis.x
	if Input.is_key_pressed(KEY_E):
		direction += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		direction -= Vector3.UP
	if direction.length_squared() > 0.0:
		var boost: float = 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
		global_position += direction.normalized() * move_speed * boost * delta
