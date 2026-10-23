class_name CowHarvest
extends Node3D

const INTERACTION_DISTANCE: float = 4.5
const BEEF_YIELD: int = 2
const HIDE_YIELD: int = 1
const BONE_YIELD: int = 1
const WANDER_RADIUS: float = 6.0
const WALK_SPEED: float = 0.45
const OBSTACLE_HEIGHT: float = 0.9
const OBSTACLE_CLEARANCE: float = 0.8
const OBSTACLE_LOOKAHEAD: float = 1.6
const DESTINATION_TRIES: int = 12
const OBSTACLE_MASK: int = 0xFFFFFFFF

@onready var visual: Node3D = $Visual
@onready var collision_shape: CollisionShape3D = $Body/CollisionShape3D
@onready var cow_animation_player: AnimationPlayer = $Visual/CowModel/AnimationPlayer

var _player: Node3D
var _inventory: InventoryUI
var _prompt_layer: CanvasLayer
var _prompt: Label
var _harvested: bool = false
var _origin: Vector3 = Vector3.ZERO
var _destination: Vector3 = Vector3.ZERO
var _pause_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _walk_time: float = 0.0
var _walk_phase: float = 0.0


func _enter_tree() -> void:
	add_to_group("interactable")
	add_to_group("persistent_cows")


func _ready() -> void:
	_create_prompt()
	_rng.randomize()
	_walk_phase = _rng.randf_range(0.0, TAU)
	_origin = global_position
	_choose_destination()
	if cow_animation_player.has_animation(&"walk"):
		cow_animation_player.play(&"walk")
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_player = current_scene.get_node_or_null("Player") as Node3D
		_inventory = current_scene.get_node_or_null("InventoryUI") as InventoryUI
	set_harvested(_harvested)


func _physics_process(delta: float) -> void:
	if SaveManager.is_restoring() or _harvested:
		return
	if _pause_timer > 0.0:
		_pause_timer = maxf(0.0, _pause_timer - delta)
		if _pause_timer == 0.0:
			_choose_destination()
		_update_idle_motion(delta)
		return

	var offset: Vector3 = _destination - global_position
	offset.y = 0.0
	if offset.length() < 0.4:
		_pause_timer = _rng.randf_range(1.5, 4.0)
		_choose_destination()
		_update_idle_motion(delta)
		return

	var direction: Vector3 = offset.normalized()
	if not _is_path_clear(direction, minf(OBSTACLE_LOOKAHEAD, offset.length())):
		_find_clear_destination()
		_update_idle_motion(delta)
		return

	global_position += direction * WALK_SPEED * delta
	rotation.y = atan2(direction.x, direction.z) + PI
	_walk_time += delta
	visual.position.y = sin(_walk_time * 4.0 + _walk_phase) * 0.018
	visual.rotation.z = sin(_walk_time * 5.0 + _walk_phase) * 0.012


func _choose_destination() -> void:
	var angle: float = _rng.randf_range(0.0, TAU)
	var distance: float = sqrt(_rng.randf()) * WANDER_RADIUS
	_destination = _origin + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)


func _update_idle_motion(delta: float) -> void:
	_walk_time += delta
	visual.position.y = sin(_walk_time * 2.2 + _walk_phase) * 0.006
	visual.rotation.z = sin(_walk_time * 1.5 + _walk_phase) * 0.004


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
	var ignored_rids: Array[RID] = []
	var cow_body: StaticBody3D = get_node("Body") as StaticBody3D
	if is_instance_valid(cow_body):
		ignored_rids.append(cow_body.get_rid())
	sweep_query.exclude = ignored_rids
	var motion_result: PackedFloat32Array = space_state.cast_motion(sweep_query)
	return motion_result.size() < 2 or motion_result[0] >= 1.0


func _find_clear_destination() -> void:
	for attempt: int in range(DESTINATION_TRIES):
		_choose_destination()
		var offset: Vector3 = _destination - global_position
		offset.y = 0.0
		if offset.length() >= 0.5 and _is_path_clear(offset.normalized(), offset.length()):
			return
	_destination = global_position
	_pause_timer = _rng.randf_range(0.8, 1.8)


func _process(_delta: float) -> void:
	if SaveManager.is_restoring():
		_prompt.visible = false
		return
	if not is_instance_valid(_player) or not is_instance_valid(_inventory):
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			_player = current_scene.get_node_or_null("Player") as Node3D
			_inventory = current_scene.get_node_or_null("InventoryUI") as InventoryUI
	if _harvested or not is_instance_valid(_player):
		_prompt.visible = false
		return
	var player_ground_position: Vector3 = Vector3(_player.global_position.x, global_position.y, _player.global_position.z)
	var in_range: bool = global_position.distance_to(player_ground_position) <= INTERACTION_DISTANCE and InteractionArbiter.is_selected(self)
	_prompt.visible = in_range
	if in_range:
		_prompt.text = "Cow\nPress E to harvest (2 Beef, 1 Hide, 1 Bone)"
	if in_range and Input.is_action_just_pressed("pickup") and is_instance_valid(_inventory) and not _inventory.is_open():
		if _inventory.add_cow_harvest_yield(BEEF_YIELD, HIDE_YIELD, BONE_YIELD):
			set_harvested(true)


func interaction_point() -> Vector3:
	return global_position + Vector3.UP * 0.8


func interaction_radius() -> float:
	return INTERACTION_DISTANCE


func is_interaction_actionable() -> bool:
	return not _harvested


func is_interaction_available() -> bool:
	return not _harvested and is_instance_valid(_inventory)


func is_harvested() -> bool:
	return _harvested


func get_inventory() -> InventoryUI:
	return _inventory


func set_harvested(value: bool) -> void:
	_harvested = value
	if is_instance_valid(visual):
		visual.visible = not value
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", value)
	if is_instance_valid(_prompt):
		_prompt.visible = false


func _create_prompt() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "PromptLayer"
	add_child(_prompt_layer)
	_prompt = Label.new()
	_prompt.name = "Prompt"
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
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.text = "Cow"
	_prompt.visible = false
	_prompt_layer.add_child(_prompt)
