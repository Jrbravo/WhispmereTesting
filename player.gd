class_name PlayerController
extends CharacterBody3D

## Third-person ground controller.
## The player is the RPG-Character that ships inside Unarmed.glb; its own
## AnimationPlayer plays the RPG clips directly (no retargeting needed).
## WASD - move (camera-relative), mouse - orbit camera, Space - jump, Shift - sprint,
## Esc - release the cursor (click to capture it again).

@export var walk_speed: float = 4.5
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.0025
@export var capture_mouse_on_start: bool = true
@export var pitch_limit_deg: float = 70.0
@export var turn_speed: float = 12.0

## Held-tool visual. The axe model is parented to the right-hand bone so it
## follows the character's existing (unarmed) animations. There is no dedicated
## axe animation yet; this only shows the tool resting in the hand.
##
## The axe is positioned in the hand bone's local space, whose units are the
## rig's centimetre units (the armature applies a 0.01 scale). AXE_LOCAL_SCALE
## grows the model into that space, and AXE_LOCAL_POSITION cancels the model's
## built-in pivot offset so the grip sits on the hand rather than floating.
const AXE_MODEL: PackedScene = preload("res://Tier1/Models/Axe.fbx")
const HAND_BONE_NAME: String = "B_R_Hand"
const AXE_LOCAL_POSITION: Vector3 = Vector3(135.0, 135.0, 0.0)
const AXE_LOCAL_ROTATION_DEG: Vector3 = Vector3(180.0, 0.0, 0.0)
const AXE_LOCAL_SCALE: float = 1800.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var model: Node3D = $Model

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _yaw: float = 0.0
var _pitch: float = -0.12
var _model_yaw: float = 0.0
var _anim: AnimationPlayer
var _current_anim: String = ""
var _axe_visual: Node3D
var _inventory: InventoryUI
var _farm_watering: bool = false


func _ready() -> void:
	add_to_group("player")
	# Keep the spring arm from colliding with this body's own capsule.
	spring_arm.add_excluded_object(get_rid())
	model.rotation.y = _model_yaw
	_apply_camera()
	_setup_character()
	_setup_axe_visual()
	if capture_mouse_on_start:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _apply_camera() -> void:
	camera_pivot.rotation = Vector3(_pitch, _yaw, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	var dialogue: NPCDialogue = get_tree().current_scene.get_node_or_null("NPCDialogue") as NPCDialogue
	if is_instance_valid(dialogue) and dialogue.is_open():
		if event.is_action_pressed("ui_cancel"):
			dialogue.close()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		_yaw -= motion.relative.x * mouse_sensitivity
		_pitch -= motion.relative.y * mouse_sensitivity
		var limit: float = deg_to_rad(pitch_limit_deg)
		_pitch = clampf(_pitch, -limit, limit)
		_apply_camera()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	_sync_held_axe()


func begin_farm_watering() -> void:
	_farm_watering = true
	velocity.x = 0.0
	velocity.z = 0.0
	_set_anim("UnarmedIdle")


func end_farm_watering() -> void:
	_farm_watering = false


func _physics_process(delta: float) -> void:
	if _farm_watering:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= _gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		model.rotation.y = lerp_angle(model.rotation.y, _model_yaw, clampf(turn_speed * delta, 0.0, 1.0))
		_set_anim("UnarmedIdle")
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis: Basis = camera_pivot.global_transform.basis
	var forward: Vector3 = -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = cam_basis.x
	right.y = 0.0
	right = right.normalized()
	var direction: Vector3 = right * input_dir.x + forward * (-input_dir.y)
	if direction.length() > 0.001:
		direction = direction.normalized()

	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		# The character mesh faces -Z, so aim its -Z along the travel direction.
		# `direction` is world space, but the model is a child of this root, so
		# express it in the root's local space. Otherwise a rotated root (e.g. a
		# spawn orientation set in the editor) is applied twice and the model
		# runs sideways relative to its movement.
		var local_direction: Vector3 = global_transform.basis.inverse() * direction
		_model_yaw = atan2(-local_direction.x, -local_direction.z)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	model.rotation.y = lerp_angle(model.rotation.y, _model_yaw, clampf(turn_speed * delta, 0.0, 1.0))
	_update_animation(direction)


func _update_animation(direction: Vector3) -> void:
	var wanted: String = "UnarmedIdle"
	if not is_on_floor():
		wanted = "UnarmedJump"
	elif direction != Vector3.ZERO:
		wanted = "UnarmedSprint" if Input.is_action_pressed("sprint") else "UnarmedRunForward"
	_set_anim(wanted)


func _set_anim(anim_name: String) -> void:
	if _anim == null or anim_name == _current_anim:
		return
	if _anim.has_animation(anim_name):
		_anim.play(anim_name)
		_current_anim = anim_name


func _setup_character() -> void:
	_anim = _find_animation_player(model)
	_loop_all_animations()
	var mesh: MeshInstance3D = _find_mesh(model)
	# The RPG-Character ships untextured; its palette texture only exists as a PSD,
	# which was converted to rpg_character_color.png.
	var tex: Texture2D = _load_character_texture()
	if mesh != null and tex != null:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mesh.material_override = mat
	_set_anim("UnarmedIdle")


func _setup_axe_visual() -> void:
	var skeleton: Skeleton3D = _find_skeleton(model)
	if skeleton == null:
		push_warning("Player: no Skeleton3D found; axe visual disabled.")
		return
	var bone_index: int = skeleton.find_bone(HAND_BONE_NAME)
	if bone_index < 0:
		push_warning("Player: bone %s not found; axe visual disabled." % HAND_BONE_NAME)
		return
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = "AxeAttachment"
	attachment.bone_idx = bone_index
	skeleton.add_child(attachment)
	var axe_instance: Node = AXE_MODEL.instantiate()
	if axe_instance == null:
		push_warning("Player: could not instance the axe model; axe visual disabled.")
		return
	var axe_root: Node3D = axe_instance as Node3D
	if axe_root == null:
		return
	axe_root.name = "HeldAxe"
	axe_root.position = AXE_LOCAL_POSITION
	axe_root.rotation = Vector3(deg_to_rad(AXE_LOCAL_ROTATION_DEG.x), deg_to_rad(AXE_LOCAL_ROTATION_DEG.y), deg_to_rad(AXE_LOCAL_ROTATION_DEG.z))
	axe_root.scale = Vector3.ONE * AXE_LOCAL_SCALE
	attachment.add_child(axe_root)
	_axe_visual = axe_root
	_axe_visual.visible = false


func _sync_held_axe() -> void:
	if not is_instance_valid(_axe_visual):
		return
	if not is_instance_valid(_inventory):
		var scene: Node = get_tree().current_scene
		if scene == null:
			return
		_inventory = scene.get_node_or_null("InventoryUI") as InventoryUI
	if not is_instance_valid(_inventory):
		return
	_axe_visual.visible = _inventory.is_axe_equipped()


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null


func _loop_all_animations() -> void:
	# The GLB clips import as non-looping, so they play once (~2s) and freeze.
	# Force every clip to loop so the character is always animating.
	if _anim == null:
		return
	for anim_name in _anim.get_animation_list():
		var a: Animation = _anim.get_animation(anim_name)
		if a != null:
			a.loop_mode = Animation.LOOP_LINEAR


func _load_character_texture() -> Texture2D:
	var path: String = "res://rpg_character_color.png"
	# Prefer the imported resource; fall back to reading the raw PNG directly
	# (works before the editor has imported the freshly generated file).
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	var img: Image = Image.load_from_file(path)
	if img != null:
		return ImageTexture.create_from_image(img)
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var r: AnimationPlayer = _find_animation_player(c)
		if r != null:
			return r
	return null


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		var r: MeshInstance3D = _find_mesh(c)
		if r != null:
			return r
	return null