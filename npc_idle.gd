class_name IdleNPC
extends CharacterBody3D

const INTERACTION_DISTANCE: float = 4.5

## Farmer interaction states
const FARMER_STATE_INITIAL: int = 0       ## "Can you build a plot?"
const FARMER_STATE_PLOT_PLACED: int = 1   ## Plot placed, "You made a friend!"
const FARMER_STATE_HELP_OFFERED: int = 2  ## "Do you want help with the farm?"
const FARMER_STATE_FARMING: int = 3       ## Autonomous berry farming loop

var _farmer_state: int = FARMER_STATE_INITIAL
var _berry_timer: Timer = Timer.new()
var _watering_timer: float = 0.0
const WOOD_WALK_SPEED: float = 2.4
const TREE_WORK_DISTANCE: float = 2.2
const TREE_WORK_SECONDS: float = 10.0
const STONE_WORK_DISTANCE: float = 3.6
const STONE_WORK_SECONDS: float = 10.0
const GRAVITY: float = 20.0
const AVOIDANCE_LOOKAHEAD: float = 3.8
const AVOIDANCE_PROBE_ANGLE: float = 0.72
const AVOIDANCE_STEER_WEIGHT: float = 2.2
const AVOIDANCE_CLEARANCE: float = 0.8
const AVOIDANCE_SIDE_LOCK_SECONDS: float = 0.45
const TARGET_APPROACH_BUFFER: float = 0.9

@onready var model: Node3D = $Model
var _animation_player: AnimationPlayer
var _player: PlayerController
var _prompt_layer: CanvasLayer
var _prompt: Label
var _dialogue: NPCDialogue
var _tree_resource: TreeResource
var _stone_resource: StoneVein
var _work_timer: Label3D
var _target_tree: Node3D
var _target_stone: Node3D
var _collecting_wood: bool = false
var _collecting_stone: bool = false
var _working_on_tree: bool = false
var _working_on_stone: bool = false
var _work_remaining: float = 0.0
var _avoidance_side_sign: float = 0.0
var _avoidance_side_lock_remaining: float = 0.0
var _idle_animation: StringName = &"UnarmedIdle"
var _walk_animation: StringName = &"UnarmedRunForward"


func _ready() -> void:
	add_to_group("interactable")
	_animation_player = _find_animation_player(model)
	_loop_animations()
	var character_mesh: MeshInstance3D = _find_mesh(model)
	if character_mesh != null:
		var current_scene: Node = get_tree().current_scene
		var plots: Array = current_scene.get_tree().get_nodes_in_group("farm_plots") if current_scene != null else []
		if not plots.is_empty():
			_farmer_state = FARMER_STATE_HELP_OFFERED
	if character_mesh != null:
		var character_material: StandardMaterial3D = StandardMaterial3D.new()
		var stone_tint: bool = String(name).contains("Stone") or String(name).contains("Miner")
		var farmer_tint: bool = String(name).contains("Farmer")
		character_material.albedo_color = Color(0.35, 0.72, 0.28, 1.0) if farmer_tint else Color(0.42, 0.44, 0.46, 1.0) if stone_tint else Color(0.32, 0.16, 0.075, 1.0)
		if farmer_tint:
			character_material.emission_enabled = true
			character_material.emission = Color(0.1, 0.3, 0.06, 1.0)
		character_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		character_material.roughness = 0.9
		character_mesh.material_override = character_material
	if _animation_player != null and _animation_player.has_animation("UnarmedIdle"):
		_animation_player.play("UnarmedIdle")
	_setup_interaction()
	_setup_work_timer()


func _setup_interaction() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_player = current_scene.get_node_or_null("Player") as PlayerController
		_tree_resource = current_scene.get_node_or_null("Nature") as TreeResource
		_stone_resource = current_scene.get_node_or_null("Props/LargeStone1") as StoneVein
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "NPCPromptLayer"
	add_child(_prompt_layer)
	_prompt = Label.new()
	_prompt.name = "TalkPrompt"
	_prompt.text = _get_farmer_prompt_text()
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_prompt.offset_top = 26.0
	_prompt.offset_bottom = 84.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 19)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.91, 0.57, 1.0))
	_prompt.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.03, 1.0))
	_prompt.add_theme_constant_override("shadow_offset_x", 2)
	_prompt.add_theme_constant_override("shadow_offset_y", 2)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	_prompt_layer.add_child(_prompt)


func _get_farmer_prompt_text() -> String:
	if String(name).contains("Farmer"):
		match _farmer_state:
			FARMER_STATE_INITIAL: return "Can you build a plot?"
			FARMER_STATE_PLOT_PLACED: return "You made a friend!\nPress E for help with the farm?"
			FARMER_STATE_HELP_OFFERED: return "Do you want help with the farm?"
		return "Farmer"
	return "Stoney\nPress E to talk" if String(name).contains("Stone") else "Woodsman\nPress E to talk"


func _setup_work_timer() -> void:
	_work_timer = Label3D.new()
	_work_timer.name = "WoodsmanTreeTimer"
	_work_timer.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_work_timer.font_size = 64
	_work_timer.outline_size = 12
	_work_timer.outline_modulate = Color(0.05, 0.035, 0.02, 1.0)
	_work_timer.modulate = Color(1.0, 0.84, 0.42, 1.0)
	_work_timer.pixel_size = 0.003
	_work_timer.no_depth_test = true
	_work_timer.position = Vector3(0.0, 2.8, 0.0)
	_work_timer.visible = false
	get_tree().current_scene.add_child.call_deferred(_work_timer)


func _process(delta: float) -> void:
	_resolve_world_references()
	var is_farmer: bool = String(name).contains("Farmer")
	if is_farmer:
		_farmer_process(delta)
	if not is_instance_valid(_player):
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			_player = current_scene.get_node_or_null("Player") as PlayerController
	if not is_instance_valid(_player):
		_prompt.visible = false
		return
	var player_ground_position: Vector3 = Vector3(_player.global_position.x, global_position.y, _player.global_position.z)
	var in_range: bool = global_position.distance_to(player_ground_position) <= INTERACTION_DISTANCE and InteractionArbiter.is_selected(self)
	_prompt.visible = in_range and not (is_instance_valid(_dialogue) and _dialogue.is_open()) and not _is_other_ui_open()
	if in_range and Input.is_action_just_pressed("pickup") and not _is_other_ui_open():
		_open_dialogue()
		get_viewport().set_input_as_handled()
	if is_farmer:
		_farmer_process(delta)
		return
	if _collecting_stone:
		_process_stone_collection(delta)
	elif _collecting_wood:
		_process_wood_collection(delta)


func _farmer_process(_delta: float) -> void:
	## Autonomous berry farming loop when help is accepted
	if _farmer_state < FARMER_STATE_HELP_OFFERED:
		return

	if _farmer_state == FARMER_STATE_HELP_OFFERED:
		## Player just accepted help - transition to farming
		_farmer_state = FARMER_STATE_FARMING
		if is_instance_valid(_berry_timer):
			_berry_timer.visible = false
		return

	## FARMER_STATE_FARMING: autonomous loop
	if not is_instance_valid(_berry_timer):
		_berry_timer = Timer.new()
		_berry_timer.name = "FarmerBerryTimer"
		_berry_timer.one_shot = false
		_berry_timer.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_berry_timer.font_size = 48
		_berry_timer.outline_size = 8
		_berry_timer.outline_modulate = Color(0.1, 0.08, 0.04, 1.0)
		_berry_timer.modulate = Color(1.0, 0.65, 0.1, 1.0)
		_berry_timer.pixel_size = 0.004
		_berry_timer.no_depth_test = true
		_berry_timer.position = Vector3(0.0, 2.5, 0.0)
		get_tree().current_scene.add_child.call_deferred(_berry_timer)

	## Check chest for berries and find empty plots
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var chest_menu: ChestInventoryMenu = ChestInventoryMenu.get_or_create(current_scene)

	## Count available berries in chest
	var berry_count: int = 0
	var _total_berry_slots: int = 0
	if is_instance_valid(chest_menu):
		berry_count = chest_menu.get_berry_count()
		_total_berry_slots = chest_menu.get_max_berry_slots()

	## If we have no berries and no plots ready, idle
	if berry_count <= 0 and _get_empty_plot_count() <= 0:
		_farmer_state = FARMER_STATE_INITIAL
		return

	## Find nearest empty plot
	var empty_plots: Array[Node3D] = _get_empty_plots()
	if empty_plots.is_empty():
		## All plots are ready for harvest, check if we can harvest
		var ready_plots: Array[Node3D] = _get_ready_plots()
		if ready_plots.is_empty():
			## No work to do, reset
			_farmer_state = FARMER_STATE_INITIAL
			if is_instance_valid(_berry_timer):
				_berry_timer.visible = false
			return

		## Attempt harvest on nearest ready plot
		var plot: Node3D = ready_plots[0]
		_harvest_from_plot(plot)
		return

	## We have empty plots - move toward nearest and plant
	var target_plot: Node3D = empty_plots[0]
	var distance: float = global_position.distance_to(target_plot.global_position)

	if distance <= 3.0:
		## Close enough - attempt to plant (consume 1 berry, start watering)
		if berry_count >= 1 and _plant_berry(target_plot, chest_menu):
			## Planting successful - start watering timer
			_watering_timer = 5.0
			_berry_timer.time_remaining = 5.0
			_berry_timer.wait_time = 5.0
			_berry_timer.one_shot = true
			_berry_timer.start()
		return
	else:
		## Move toward the plot
		var direction: Vector3 = target_plot.global_position - global_position
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			rotation.y = atan2(-direction.x, -direction.z)
		velocity = Vector3.ZERO
		move_and_slide()
		return

	## State transitions after watering/growing/harvesting are handled
	## by the timer callbacks below


func _get_empty_plot_count() -> int:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return 0
	var plots: Array = get_tree().get_nodes_in_group("farm_plots")
	var empty_count: int = 0
	for plot: Node3D in plots:
		var farm_plot: FarmPlot = plot.get_script() as FarmPlot
		if is_instance_valid(farm_plot) and farm_plot.stage == FarmPlot.STAGE_EMPTY:
			empty_count += 1
	return empty_count


func _get_empty_plots() -> Array[Node3D]:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return []
	var plots: Array = get_tree().get_nodes_in_group("farm_plots")
	var empty_plots: Array[Node3D] = []
	for plot: Node3D in plots:
		var farm_plot: FarmPlot = plot.get_script() as FarmPlot
		if is_instance_valid(farm_plot) and farm_plot.stage == FarmPlot.STAGE_EMPTY:
			empty_plots.append(plot)
	return empty_plots


func _get_ready_plots() -> Array[Node3D]:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return []
	var plots: Array = get_tree().get_nodes_in_group("farm_plots")
	var ready_plots: Array[Node3D] = []
	for plot: Node3D in plots:
		var farm_plot: FarmPlot = plot.get_script() as FarmPlot
		if is_instance_valid(farm_plot) and farm_plot.stage == FarmPlot.STAGE_READY:
			ready_plots.append(plot)
	return ready_plots


func _plant_berry(plot_node: Node3D, chest_menu: ChestInventoryMenu) -> bool:
	var farm_plot: FarmPlot = plot_node.get_script() as FarmPlot
	if not is_instance_valid(farm_plot):
		return false
	if farm_plot.stage != FarmPlot.STAGE_EMPTY:
		return false
	## Consume 1 berry from chest
	var success: bool = chest_menu.remove_berry(1)
	if not success:
		return false
	## Start the plot growing
	farm_plot.start_growing()
	return true


func _harvest_from_plot(plot_node: Node3D) -> void:
	var farm_plot: FarmPlot = plot_node.get_script() as FarmPlot
	if not is_instance_valid(farm_plot):
		return
	## Attempt atomic harvest (gives 3 berries if room)
	farm_plot.harvest()
	## After harvest, plot resets to EMPTY
	## Farmer will then look for new empty plots in the next loop iteration
	_farmer_state = FARMER_STATE_FARMING


func interaction_point() -> Vector3:
	return global_position


func interaction_radius() -> float:
	return INTERACTION_DISTANCE


func is_interaction_actionable() -> bool:
	## Return true if interaction is actionable for this NPC
	return not String(name).contains("Farmer")


func is_interaction_available() -> bool:
	## Return true if interaction is available for this NPC
	return not String(name).contains("Farmer")


func _resolve_world_references() -> void:
	if is_instance_valid(_player) and is_instance_valid(_tree_resource) and is_instance_valid(_stone_resource):
		return
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	if not is_instance_valid(_player):
		_player = current_scene.get_node_or_null("Player") as PlayerController
	if not is_instance_valid(_tree_resource):
		_tree_resource = current_scene.get_node_or_null("Nature") as TreeResource
	if not is_instance_valid(_stone_resource):
		_stone_resource = current_scene.get_node_or_null("Props/LargeStone1") as StoneVein


func _physics_process(delta: float) -> void:
	if SaveManager.is_restoring(): return
	_avoidance_side_lock_remaining = maxf(0.0, _avoidance_side_lock_remaining - delta)
	if _collecting_stone:
		if _working_on_stone:
			velocity.x = 0.0
			velocity.z = 0.0
			velocity.y = -GRAVITY * delta
			move_and_slide()
			return
		if not is_instance_valid(_target_stone):
			_select_next_stone()
			return
		var stone_destination: Vector3 = _target_stone.global_position
		stone_destination.y = global_position.y
		if _flat_distance(global_position, stone_destination) <= STONE_WORK_DISTANCE:
			_begin_stone_work()
			return
		var stone_direction: Vector3 = stone_destination - global_position
		stone_direction.y = 0.0
		if stone_direction.length_squared() <= 0.001:
			_begin_stone_work()
			return
		stone_direction = _get_steered_direction(stone_direction.normalized())
		velocity.x = stone_direction.x * WOOD_WALK_SPEED
		velocity.z = stone_direction.z * WOOD_WALK_SPEED
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.y = 0.0
		rotation.y = atan2(-stone_direction.x, -stone_direction.z)
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	if is_stone_worker() or not _collecting_wood:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -GRAVITY * delta
		move_and_slide()
		return
	if _working_on_tree:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -GRAVITY * delta
		move_and_slide()
		return
	if not is_instance_valid(_target_tree):
		_select_next_tree()
		return
	var destination: Vector3 = _target_tree.global_position
	destination.y = global_position.y
	var distance: float = global_position.distance_to(destination)
	if distance <= TREE_WORK_DISTANCE:
		_begin_tree_work()
		return
	var direction: Vector3 = destination - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		_begin_tree_work()
		return
	direction = _get_steered_direction(direction.normalized())
	velocity.x = direction.x * WOOD_WALK_SPEED
	velocity.z = direction.z * WOOD_WALK_SPEED
	var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	rotation.y = atan2(-direction.x, -direction.z)
	move_and_slide()
	if _flat_distance(global_position, destination) <= TREE_WORK_DISTANCE + (AVOIDANCE_CLEARANCE if is_on_wall() else 0.0):
		_begin_tree_work()


func _get_steered_direction(desired_direction: Vector3) -> Vector3:
	var avoidance_target: Vector3 = _target_stone.global_position if _collecting_stone and is_instance_valid(_target_stone) else _target_tree.global_position
	var target_distance: float = _flat_distance(global_position, avoidance_target)
	var work_distance: float = STONE_WORK_DISTANCE if _collecting_stone else TREE_WORK_DISTANCE
	if target_distance <= work_distance + TARGET_APPROACH_BUFFER:
		_avoidance_side_sign = 0.0
		_avoidance_side_lock_remaining = 0.0
		return desired_direction
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = global_position + Vector3.UP * 0.9
	var forward_end: Vector3 = origin + desired_direction * AVOIDANCE_LOOKAHEAD
	var direct_hit: Dictionary = _probe_clearance(space_state, origin, forward_end)
	if direct_hit.is_empty():
		return desired_direction
	var side_sign: float = _avoidance_side_sign if _avoidance_side_lock_remaining > 0.0 else 1.0
	var right_direction: Vector3 = Vector3(desired_direction.z, 0.0, -desired_direction.x)
	var left_direction: Vector3 = -right_direction
	var right_hit: Dictionary = _probe_direction(space_state, origin, desired_direction, right_direction)
	var left_hit: Dictionary = _probe_direction(space_state, origin, desired_direction, left_direction)
	if _avoidance_side_lock_remaining <= 0.0:
		if right_hit.is_empty() and not left_hit.is_empty():
			side_sign = 1.0
		elif left_hit.is_empty() and not right_hit.is_empty():
			side_sign = -1.0
		elif right_hit.is_empty() and left_hit.is_empty():
			var to_target: Vector3 = avoidance_target - global_position
			to_target.y = 0.0
			side_sign = 1.0 if right_direction.dot(to_target) >= left_direction.dot(to_target) else -1.0
		else:
			var right_distance: float = global_position.distance_to(right_hit.get("position", global_position))
			var left_distance: float = global_position.distance_to(left_hit.get("position", global_position))
			side_sign = 1.0 if right_distance >= left_distance else -1.0
		_avoidance_side_sign = side_sign
		_avoidance_side_lock_remaining = AVOIDANCE_SIDE_LOCK_SECONDS
	var steer_direction: Vector3 = (desired_direction + (right_direction * side_sign * AVOIDANCE_STEER_WEIGHT)).normalized()
	return steer_direction


func _probe_direction(space_state: PhysicsDirectSpaceState3D, origin: Vector3, forward: Vector3, side: Vector3) -> Dictionary:
	var probe_direction: Vector3 = (forward + side * tan(AVOIDANCE_PROBE_ANGLE)).normalized()
	return _probe_clearance(space_state, origin, origin + probe_direction * AVOIDANCE_LOOKAHEAD)


func _probe_clearance(space_state: PhysicsDirectSpaceState3D, origin: Vector3, end: Vector3) -> Dictionary:
	var clearance_shape: SphereShape3D = SphereShape3D.new()
	clearance_shape.radius = AVOIDANCE_CLEARANCE
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = clearance_shape
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.motion = end - origin
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	var motion_result: PackedFloat32Array = space_state.cast_motion(query)
	if motion_result.size() < 2 or motion_result[0] >= 1.0:
		return {}
	var collision_position: Vector3 = origin + (end - origin) * motion_result[0]
	return {"position": collision_position}


func _process_stone_collection(delta: float) -> void:
	if not _working_on_stone and not is_instance_valid(_target_stone):
		_select_next_stone()
	elif _working_on_stone:
		_work_remaining = maxf(0.0, _work_remaining - delta)
		if is_instance_valid(_work_timer):
			_work_timer.text = "%d" % ceili(_work_remaining)
		if _work_remaining <= 0.0:
			_finish_stone_work()


func start_stone_collection() -> void:
	if _collecting_stone:
		return
	_collecting_wood = false
	_working_on_tree = false
	_target_tree = null
	_collecting_stone = true
	_working_on_stone = false
	_select_next_stone()


func _select_next_stone() -> void:
	if not is_instance_valid(_stone_resource):
		_stop_stone_collection()
		return
	var available_deposits: Array[Node3D] = _stone_resource.get_available_deposits()
	if available_deposits.is_empty():
		_stop_stone_collection()
		return
	var closest_deposit: Node3D = available_deposits[0]
	var closest_distance: float = _flat_distance(global_position, closest_deposit.global_position)
	for deposit: Node3D in available_deposits:
		var distance: float = _flat_distance(global_position, deposit.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_deposit = deposit
	_target_stone = closest_deposit
	_working_on_stone = false
	if _animation_player != null and _animation_player.has_animation(_walk_animation):
		_animation_player.play(_walk_animation)


func _process_wood_collection(delta: float) -> void:
	if _working_on_tree:
		_work_remaining = maxf(0.0, _work_remaining - delta)
		if is_instance_valid(_work_timer):
			_work_timer.text = "%d" % ceili(_work_remaining)
		if _work_remaining <= 0.0:
			_finish_tree_work()


func is_stone_worker() -> bool:
	return String(name).contains("Stone") or String(name).contains("Miner")


## Authoritative, persistent recruitment/job state for this NPC.
func is_working() -> bool:
	return _collecting_wood or _collecting_stone


func get_job_state() -> Dictionary:
	return {"working": is_working()}


## Applies persisted recruitment state before AI runs. Transient targets and
## timers are intentionally not restored; the NPC picks a fresh target.
func set_job_state(working: bool) -> void:
	_resolve_world_references()
	if working:
		if is_stone_worker():
			if not _collecting_stone:
				start_stone_collection()
		elif not _collecting_wood:
			start_wood_collection()
	else:
		if _collecting_wood:
			_stop_wood_collection()
		if _collecting_stone:
			_stop_stone_collection()
	if _animation_player != null and not working and _animation_player.has_animation(_idle_animation):
		_animation_player.play(_idle_animation)


func start_wood_collection() -> void:
	if _collecting_wood:
		return
	_collecting_wood = true
	_working_on_tree = false
	_select_next_tree()


func _select_next_tree() -> void:
	if not is_instance_valid(_tree_resource):
		_stop_wood_collection()
		return
	var available_trees: Array[Node3D] = _tree_resource.get_available_trees()
	if available_trees.is_empty():
		_stop_wood_collection()
		return
	var closest_tree: Node3D = available_trees[0]
	var closest_distance: float = _flat_distance(global_position, closest_tree.global_position)
	for tree: Node3D in available_trees:
		var distance: float = _flat_distance(global_position, tree.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_tree = tree
	_target_tree = closest_tree
	_working_on_tree = false
	if _animation_player != null and _animation_player.has_animation(_walk_animation):
		_animation_player.play(_walk_animation)


func _flat_distance(first: Vector3, second: Vector3) -> float:
	var first_flat: Vector2 = Vector2(first.x, first.z)
	var second_flat: Vector2 = Vector2(second.x, second.z)
	return first_flat.distance_to(second_flat)


func _begin_stone_work() -> void:
	_working_on_stone = true
	var work_direction: Vector3 = global_position.direction_to(_target_stone.global_position)
	work_direction.y = 0.0
	if work_direction.length_squared() > 0.001:
		rotation.y = atan2(-work_direction.x, -work_direction.z)
	_work_remaining = STONE_WORK_SECONDS
	velocity = Vector3.ZERO
	if _animation_player != null and _animation_player.has_animation(_idle_animation):
		_animation_player.play(_idle_animation)
	if is_instance_valid(_work_timer):
		_work_timer.text = "%d" % ceili(_work_remaining)
		_work_timer.global_position = _target_stone.global_position + Vector3(0.0, 2.7, 0.0)
		_work_timer.visible = true


func _finish_stone_work() -> void:
	if is_instance_valid(_stone_resource) and is_instance_valid(_target_stone):
		_stone_resource.mark_deposit_harvested(_target_stone)
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			var chest_menu: ChestInventoryMenu = ChestInventoryMenu.get_or_create(current_scene)
			var stone_added: int = chest_menu.add_stone(5)
			if stone_added < 5:
				push_warning("Chest storage is full; Stoney could only store %d of 5 Stone." % stone_added)
	_working_on_stone = false
	if is_instance_valid(_work_timer):
		_work_timer.visible = false
	_target_stone = null
	_select_next_stone()


func _stop_stone_collection() -> void:
	_collecting_stone = false
	_working_on_stone = false
	velocity = Vector3.ZERO
	if is_instance_valid(_work_timer):
		_work_timer.visible = false
	if _animation_player != null and _animation_player.has_animation(_idle_animation):
		_animation_player.play(_idle_animation)


func _begin_tree_work() -> void:
	_working_on_tree = true
	var work_direction: Vector3 = global_position.direction_to(_target_tree.global_position)
	work_direction.y = 0.0
	if work_direction.length_squared() > 0.001:
		rotation.y = atan2(-work_direction.x, -work_direction.z)
	_work_remaining = TREE_WORK_SECONDS
	velocity = Vector3.ZERO
	if _animation_player != null and _animation_player.has_animation(_idle_animation):
		_animation_player.play(_idle_animation)
	if is_instance_valid(_work_timer):
		_work_timer.text = "%d" % ceili(_work_remaining)
		_work_timer.global_position = _target_tree.global_position + Vector3(0.0, 3.0, 0.0)
		_work_timer.visible = true


func _finish_tree_work() -> void:
	if is_instance_valid(_tree_resource) and is_instance_valid(_target_tree):
		_tree_resource.mark_tree_harvested(_target_tree)
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			var chest_menu: ChestInventoryMenu = ChestInventoryMenu.get_or_create(current_scene)
			var wood_added: int = chest_menu.add_wood(5)
			if wood_added < 5:
				push_warning("Chest storage is full; Woodsman could only store %d of 5 Wood." % wood_added)
	_working_on_tree = false
	if is_instance_valid(_work_timer):
		_work_timer.visible = false
	_target_tree = null
	_select_next_tree()


func _stop_wood_collection() -> void:
	_collecting_wood = false
	_working_on_tree = false
	velocity = Vector3.ZERO
	if is_instance_valid(_work_timer):
		_work_timer.visible = false
	if _animation_player != null and _animation_player.has_animation(_idle_animation):
		_animation_player.play(_idle_animation)


func _is_other_ui_open() -> bool:
	var current_scene: Node = get_tree().current_scene
	var inventory: InventoryUI = current_scene.get_node_or_null("InventoryUI") as InventoryUI
	var crafting: CraftingMenu = current_scene.get_node_or_null("CraftingMenu") as CraftingMenu
	if (is_instance_valid(inventory) and inventory.is_open()) or (is_instance_valid(crafting) and crafting.is_open()):
		return true
	if current_scene == null:
		return false
	for ui_node: Node in get_tree().get_nodes_in_group("blocking_ui"):
		if ui_node is Control and (ui_node as Control).is_visible_in_tree():
			return true
	var campfire: CampfireMenu = current_scene.get_node_or_null("CampfireMenu") as CampfireMenu
	var dialogue: NPCDialogue = current_scene.get_node_or_null("NPCDialogue") as NPCDialogue
	var chest: ChestInventoryMenu = current_scene.get_node_or_null("ChestInventoryMenu") as ChestInventoryMenu
	return (is_instance_valid(campfire) and campfire.is_open()) or (is_instance_valid(dialogue) and dialogue.is_open()) or (is_instance_valid(chest) and chest.is_open())


func _open_dialogue() -> void:
	if SaveManager.is_restoring():
		return
	var is_stoney: bool = String(name).contains("Stone") or String(name).contains("Miner")
	var is_farmer: bool = String(name).contains("Farmer")
	var wanted_name: String = "NPCDialogue_Stoney" if is_stoney else ("NPCDialogue_Farmer" if is_farmer else "NPCDialogue")
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var authoritative_node: Node = current_scene.get_node_or_null(wanted_name)
	if not is_instance_valid(authoritative_node):
		for candidate: Node in get_tree().get_nodes_in_group("npc_dialogue"):
			var possible: NPCDialogue = candidate as NPCDialogue
			if is_instance_valid(possible) and current_scene.is_ancestor_of(possible) and possible.is_configured_for_stoney() == is_stoney:
				authoritative_node = possible
				break
	if not is_instance_valid(authoritative_node):
		_dialogue = NPCDialogue.new()
		_dialogue.name = wanted_name
		_dialogue.configure_for_stoney(is_stoney, is_farmer)
		current_scene.add_child(_dialogue)
	else:
		_dialogue = authoritative_node as NPCDialogue
	if not is_instance_valid(_dialogue):
		return
	_dialogue.configure_for_stoney(is_stoney, is_farmer)
	_dialogue.open()
	if not is_instance_valid(_dialogue):
		return
	_dialogue.configure_for_stoney(is_stoney)
	_dialogue.open()


func _loop_animations() -> void:
	if _animation_player == null:
		return
	for animation_name in _animation_player.get_animation_list():
		var animation: Animation = _animation_player.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: MeshInstance3D = _find_mesh(child)
		if found != null:
			return found
	return null