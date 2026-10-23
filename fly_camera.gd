class_name FlyCamera
extends Camera3D

## Simple free-fly camera for exploring the town.
## WASD - move, Q/E - down/up, hold Shift - boost, hold right mouse - look around, Esc - release cursor.

@export var speed: float = 15.0
@export var boost_multiplier: float = 4.0
@export var mouse_sensitivity: float = 0.0025


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mb.pressed else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event
		rotate_y(-mm.relative.x * mouse_sensitivity)
		rotate_object_local(Vector3.RIGHT, -mm.relative.y * mouse_sensitivity)


func _process(delta: float) -> void:
	var dir: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		dir += transform.basis.x
	if Input.is_key_pressed(KEY_E):
		dir += transform.basis.y
	if Input.is_key_pressed(KEY_Q):
		dir -= transform.basis.y

	if dir != Vector3.ZERO:
		var spd: float = speed * (boost_multiplier if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		position += dir.normalized() * spd * delta

	if Input.is_key_pressed(KEY_ESCAPE):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE