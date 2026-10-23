class_name ChickenWander
extends Node3D

const CHICKEN_SCENE: PackedScene = preload("res://stylooanimalassetpack/glb/chichen.glb")

@export var wander_radius: float = 8.0
@export var walk_speed: float = 0.65
@export var interaction_distance: float = 4.5
@export var raw_meat_amount: int = 1

const OBSTACLE_HEIGHT: float = 0.9
const OBSTACLE_CLEARANCE: float = 0.6
const OBSTACLE_LOOKAHEAD: float = 1.6
const DESTINATION_TRIES: int = 12
const OBSTACLE_MASK: int = 0xFFFFFFFF

var _origin: Vector3 = Vector3.ZERO
var _destination: Vector3 = Vector3.ZERO
var _pause_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _model: Node3D
var _walk_time: float = 0.0
var _walk_phase: float = 0.0
var _player: Node3D
var _inventory: InventoryUI
var _prompt_layer: CanvasLayer
var _prompt: Label

func _ready() -> void:
	add_to_group("chickens")
	add_to_group("persistent_world_objects")
	add_to_group("interactable")
	_rng.randomize()
	_model = CHICKEN_SCENE.instantiate() as Node3D
	add_child(_model)
	# The supplied chicken is a static skinned mesh with no imported animation.
	# Give its body and head a subtle procedural peck/bob while it wanders.
	_walk_phase = _rng.randf_range(0.0, TAU)
	_origin = global_position
	_choose_destination()
	_player = get_tree().current_scene.get_node_or_null("Player") as Node3D
	_inventory = get_tree().current_scene.get_node_or_null("InventoryUI") as InventoryUI
	_create_prompt()

func _physics_process(delta: float) -> void:
	if SaveManager.is_restoring():
		return
	if _pause_timer > 0.0:
		_pause_timer = maxf(0.0, _pause_timer - delta)
		if _pause_timer == 0.0:
			_choose_destination()
		_update_idle_motion(delta)
		return

	var offset: Vector3 = _destination - global_position
	offset.y = 0.0
	if offset.length() < 0.35:
		_pause_timer = _rng.randf_range(1.0, 3.2)
		_choose_destination()
		_update_idle_motion(delta)
		return

	var direction: Vector3 = offset.normalized()
	if not _is_path_clear(direction, OBSTACLE_LOOKAHEAD):
		_find_clear_destination()
		_update_idle_motion(delta)
		return
	global_position += direction * walk_speed * delta
	rotation.y = atan2(direction.x, direction.z) + PI
	_walk_time += delta
	_model.position.y = sin(_walk_time * 9.0 + _walk_phase) * 0.035
	_model.rotation.z = sin(_walk_time * 12.0 + _walk_phase) * 0.025

func _process(_delta: float) -> void:
	if SaveManager.is_restoring():
		return
	if not is_instance_valid(_player):
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			_player = current_scene.get_node_or_null("Player") as Node3D
	if not is_instance_valid(_player):
		_prompt.visible = false
		return
	var in_range: bool = global_position.distance_to(_player.global_position) <= interaction_distance and InteractionArbiter.is_selected(self)
	_prompt.visible = in_range
	if in_range and Input.is_action_just_pressed("pickup") and is_instance_valid(_inventory) and not _inventory.is_open():
		var added_amount: int = _inventory.add_raw_meat(raw_meat_amount)
		if added_amount == raw_meat_amount:
			queue_free()


func interaction_point() -> Vector3:
	return global_position


func interaction_radius() -> float:
	return interaction_distance


func is_interaction_actionable() -> bool:
	return true


func is_interaction_available() -> bool:
	return is_instance_valid(_inventory)

func _create_prompt() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "PromptLayer"
	add_child(_prompt_layer)
	_prompt = Label.new()
	_prompt.name = "ChickenPrompt"
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_prompt.offset_top = 26.0
	_prompt.offset_bottom = 86.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 19)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.91, 0.57, 1.0))
	_prompt.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.03, 1.0))
	_prompt.add_theme_constant_override("shadow_offset_x", 2)
	_prompt.add_theme_constant_override("shadow_offset_y", 2)
	_prompt.text = "Chicken\nPress E to pick up"
	_prompt.visible = false
	_prompt_layer.add_child(_prompt)

## Used by Chef: removes this chicken from the world and returns its raw meat.
func collect_for_npc() -> int:
	queue_free()
	return raw_meat_amount


func _update_idle_motion(delta: float) -> void:
	_walk_time += delta
	_model.position.y = sin(_walk_time * 2.5 + _walk_phase) * 0.012
	_model.rotation.z = sin(_walk_time * 1.7 + _walk_phase) * 0.01

func _choose_destination() -> void:
	var angle: float = _rng.randf_range(0.0, TAU)
	var distance: float = sqrt(_rng.randf()) * wander_radius
	_destination = _origin + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)


## Returns true when a sphere (the chicken's buffer) can travel along `direction`
## for `distance` without touching a collider. Starting inside a collider counts
## as clear so a chicken that spawns against an object can still walk out.
func _is_path_clear(direction: Vector3, distance: float) -> bool:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = global_position + Vector3.UP * OBSTACLE_HEIGHT
	var sweep_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = OBSTACLE_CLEARANCE
	sweep_query.shape = shape
	sweep_query.transform = Transform3D(Basis.IDENTITY, origin)
	sweep_query.motion = direction * distance
	sweep_query.collision_mask = OBSTACLE_MASK
	var motion_result: PackedFloat32Array = space_state.cast_motion(sweep_query)
	if motion_result.size() < 2:
		return true
	return motion_result[0] >= 1.0


## Picks a new wander spot whose route is clear. If none is found, the chicken pauses.
func _find_clear_destination() -> void:
	for attempt: int in range(DESTINATION_TRIES):
		_choose_destination()
		var offset: Vector3 = _destination - global_position
		offset.y = 0.0
		if offset.length() < 0.5:
			continue
		if _is_path_clear(offset.normalized(), offset.length()):
			return
	_destination = global_position
	_pause_timer = _rng.randf_range(0.5, 1.5)

