class_name ChefNPC
extends CharacterBody3D

## Chef talks with E. If a campfire exists he asks to use it (Yes/No do nothing
## except Yes, which starts his helper loop); otherwise he asks you to make one.
## Helper loop: gather chicken meat (3 seconds each), carry 3 to the nearest
## campfire, let it cook, then go back for more.

const GRAVITY: float = 20.0
const CHEF_COLOR: Color = Color(0.78, 0.12, 0.1, 1.0)
const IDLE_ANIMATION: StringName = &"UnarmedIdle"
const INTERACTION_DISTANCE: float = 4.5
const WALK_SPEED: float = 2.2
const ARRIVE_DISTANCE: float = 1.6
const GATHER_SECONDS: float = 3.0
## How many gathered items the Chef carries before walking back to the campfire.
const MEAT_PER_BATCH: int = 3
## Gatherable ingredient nodes: group name -> the inventory item it yields.
## Raw chicken meat comes from the "chickens" group (the chicken yields it).
const FORAGE_GROUPS: Dictionary = {
	"berry_pickups": "Wild Berries",
	"mushroom_pickups": "Wild Mushrooms",
	"herb_pickups": "Wild Herbs",
}
const AVOIDANCE_LOOKAHEAD: float = 3.8
const AVOIDANCE_PROBE_ANGLE: float = 0.72
const AVOIDANCE_STEER_WEIGHT: float = 2.2
const AVOIDANCE_CLEARANCE: float = 0.8

enum Task { IDLE, GATHERING, TO_CAMPFIRE, COOKING }

@onready var model: Node3D = $Model
var _animation_player: AnimationPlayer
var _player: PlayerController
var _prompt_layer: CanvasLayer
var _prompt: Label
var _dialogue_layer: CanvasLayer
var _dialogue_root: CenterContainer
var _dialogue_message: Label
var _yes_button: Button
var _no_button: Button
var _dialogue_open: bool = false
var _task: int = Task.IDLE
var _carried: Dictionary = {}
var _work_remaining: float = 0.0
var _target_ingredient: Node3D
var _target_campfire: Node3D
var _walk_animation: StringName = &"UnarmedRunForward"
var _helping: bool = false
var _thanked: bool = false
var _friend_made: bool = false
var _friend_layer: CanvasLayer
var _friend_overlay: ColorRect
var _friend_message: Label
var _friend_tween: Tween


func _ready() -> void:
	_animation_player = _find_animation_player(model)
	if _animation_player != null:
		for animation_name: StringName in _animation_player.get_animation_list():
			var animation: Animation = _animation_player.get_animation(animation_name)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR
		if _animation_player.has_animation(IDLE_ANIMATION):
			_animation_player.play(IDLE_ANIMATION)
	for character_mesh: MeshInstance3D in _find_meshes(model):
		var chef_material: StandardMaterial3D = StandardMaterial3D.new()
		chef_material.albedo_color = CHEF_COLOR
		chef_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		chef_material.roughness = 0.9
		character_mesh.material_override = chef_material
	add_to_group("interactable")
	_build_prompt()
	_build_dialogue()
	_build_friend_overlay()


func _process(_delta: float) -> void:
	_resolve_runtime_references()
	if not is_instance_valid(_player):
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			_player = current_scene.get_node_or_null("Player") as PlayerController
	if not is_instance_valid(_player):
		_prompt.visible = false
		return
	var player_ground_position: Vector3 = Vector3(_player.global_position.x, global_position.y, _player.global_position.z)
	var in_range: bool = global_position.distance_to(player_ground_position) <= INTERACTION_DISTANCE and InteractionArbiter.is_selected(self)
	var can_talk: bool = not _thanked and not _friend_made
	_prompt.visible = in_range and can_talk and not _dialogue_open and not _is_other_ui_open()
	if _dialogue_open:
		if Input.is_action_just_pressed("pickup"):
			_on_exit_pressed()
			get_viewport().set_input_as_handled()
	elif can_talk and in_range and Input.is_action_just_pressed("pickup") and not _is_other_ui_open():
		_open_dialogue()
		get_viewport().set_input_as_handled()


func interaction_point() -> Vector3:
	return global_position


func interaction_radius() -> float:
	return INTERACTION_DISTANCE


func is_interaction_actionable() -> bool:
	return not _thanked and not _friend_made


func is_interaction_available() -> bool:
	return not _thanked and not _friend_made


func _resolve_runtime_references() -> void:
	if not is_processing():
		set_process(true)
	if not is_physics_processing():
		set_physics_process(true)
	if not is_instance_valid(_player):
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			_player = current_scene.get_node_or_null("Player") as PlayerController
	if is_instance_valid(_target_ingredient) and not _target_ingredient.is_inside_tree():
		_target_ingredient = null
	if is_instance_valid(_target_campfire) and not _target_campfire.is_inside_tree():
		_target_campfire = null
	if _helping and _task == Task.GATHERING and not is_instance_valid(_target_ingredient):
		_target_ingredient = _nearest_ingredient()
	if _helping and _task in [Task.TO_CAMPFIRE, Task.COOKING] and not is_instance_valid(_target_campfire):
		_target_campfire = _nearest_campfire()
		if _target_campfire == null:
			_task = Task.GATHERING
			_carried.clear()

func _physics_process(delta: float) -> void:
	if SaveManager.is_restoring(): return
	if _helping:
		_run_helper_task(delta)
		return
	velocity.x = 0.0
	velocity.z = 0.0
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()


## Chef's loop: gather the nearest ingredients (chicken meat, berries,
## mushrooms, herbs) until he is carrying a batch, walk to the campfire, drop
## them off, then go back for more.
func restore_helper_activity() -> void:
	if not _friend_made:
		return
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	set_physics_process(true)
	_helping = true
	_task = Task.GATHERING
	_carried.clear()
	_work_remaining = GATHER_SECONDS
	_target_ingredient = null
	_target_campfire = null
	call_deferred("_resume_helper_after_restore")

func _run_helper_task(delta: float) -> void:
	match _task:
		Task.GATHERING:
			_process_gathering(delta)
		Task.TO_CAMPFIRE:
			_process_walk_to_campfire(delta)
		Task.COOKING:
			_process_cooking(delta)
		_:
			_stop_helping()


func _process_gathering(delta: float) -> void:
	if not is_instance_valid(_target_ingredient):
		_target_ingredient = _nearest_ingredient()
		if _target_ingredient == null:
			_stand_still(delta)
			return
	if not _walk_toward(_target_ingredient, delta):
		return
	_work_remaining -= delta
	if _work_remaining > 0.0:
		_stand_still(delta)
		return
	_harvest_target()
	_target_ingredient = null
	_work_remaining = GATHER_SECONDS
	if _carried_total() >= MEAT_PER_BATCH:
		_target_campfire = _nearest_campfire()
		if _target_campfire == null:
			_stop_helping()
		else:
			_task = Task.TO_CAMPFIRE


## Takes whatever the current gathering target yields and adds it to the load.
func _harvest_target() -> void:
	if not is_instance_valid(_target_ingredient):
		return
	var chicken: ChickenWander = _target_ingredient as ChickenWander
	if is_instance_valid(chicken):
		_add_carried("Raw Meat", chicken.collect_for_npc())
		return
	var forage: WildResource = _target_ingredient as WildResource
	if is_instance_valid(forage):
		var reward: Dictionary = forage.collect_for_npc()
		for item_value: Variant in reward.keys():
			_add_carried(String(item_value), int(reward[item_value]))


func _add_carried(item_name: String, amount: int) -> void:
	if amount <= 0:
		return
	_carried[item_name] = int(_carried.get(item_name, 0)) + amount


func _carried_total() -> int:
	var total: int = 0
	for amount: int in _carried.values():
		total += amount
	return total


func _process_walk_to_campfire(delta: float) -> void:
	if not is_instance_valid(_target_campfire):
		_stop_helping()
		return
	if _walk_toward(_target_campfire, delta):
		_task = Task.COOKING


func _process_cooking(delta: float) -> void:
	var campfire: PlacedCampfire = _target_campfire as PlacedCampfire
	if not is_instance_valid(campfire):
		_stop_helping()
		return
	_deposit_carried(campfire)
	_stand_still(delta)
	if campfire.meat_still_cooking() or _carried_total() > 0:
		# Wait while the raw stack is cooking, or until there is room for the rest.
		return
	# Everything is dropped off and cooking. Go back for more ingredients.
	_target_campfire = null
	_task = Task.GATHERING
	_work_remaining = GATHER_SECONDS


## Unloads the carried items: raw meat goes into the campfire's raw stack so it
## cooks, and every other ingredient goes into the campfire's stock slots.
func _deposit_carried(campfire: PlacedCampfire) -> void:
	for item_value: Variant in _carried.keys():
		var item_name: String = String(item_value)
		var remaining: int = int(_carried[item_name])
		while remaining > 0:
			var accepted: int = 0
			if item_name == "Raw Meat":
				accepted = 1 if campfire.accept_raw_meat_from_npc() else 0
			else:
				accepted = campfire.accept_ingredient_from_npc(item_name)
			if accepted <= 0:
				break
			remaining -= accepted
		if remaining <= 0:
			_carried.erase(item_name)
		else:
			_carried[item_name] = remaining


func _stop_helping() -> void:
	_helping = false
	_task = Task.IDLE
	_target_ingredient = null
	_target_campfire = null
	_set_walk_animation(false)


## Moves toward `target` on the ground. Returns true once within reach.
func _walk_toward(target: Node3D, delta: float) -> bool:
	if not is_instance_valid(target):
		return false
	var destination: Vector3 = target.global_position
	destination.y = global_position.y
	var offset: Vector3 = destination - global_position
	offset.y = 0.0
	if offset.length() <= ARRIVE_DISTANCE:
		_stand_still(delta)
		_set_walk_animation(false)
		return true
	var direction: Vector3 = _get_steered_direction(offset.normalized())
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	rotation.y = atan2(-direction.x, -direction.z)
	_set_walk_animation(true)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	return false


## Same obstacle steering the Woodsman and Stoney use: probe ahead with a sphere
## buffer, and if something is in the way, sidestep toward the clearer side.
func _get_steered_direction(desired_direction: Vector3) -> Vector3:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = global_position + Vector3.UP * 0.9
	var forward_end: Vector3 = origin + desired_direction * AVOIDANCE_LOOKAHEAD
	if _probe_clearance(space_state, origin, forward_end).is_empty():
		return desired_direction
	var right_direction: Vector3 = Vector3(desired_direction.z, 0.0, -desired_direction.x)
	var left_direction: Vector3 = -right_direction
	var right_hit: Dictionary = _probe_side(space_state, origin, desired_direction, right_direction)
	var left_hit: Dictionary = _probe_side(space_state, origin, desired_direction, left_direction)
	var side_sign: float = 1.0
	if right_hit.is_empty() and not left_hit.is_empty():
		side_sign = 1.0
	elif left_hit.is_empty() and not right_hit.is_empty():
		side_sign = -1.0
	elif right_hit.is_empty() and left_hit.is_empty():
		var to_target: Vector3 = _current_destination() - global_position
		to_target.y = 0.0
		side_sign = 1.0 if right_direction.dot(to_target) >= left_direction.dot(to_target) else -1.0
	else:
		var right_distance: float = global_position.distance_to(right_hit.get("position", global_position))
		var left_distance: float = global_position.distance_to(left_hit.get("position", global_position))
		side_sign = 1.0 if right_distance >= left_distance else -1.0
	return (desired_direction + right_direction * side_sign * AVOIDANCE_STEER_WEIGHT).normalized()


func _probe_side(space_state: PhysicsDirectSpaceState3D, origin: Vector3, forward: Vector3, side: Vector3) -> Dictionary:
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
	return {"position": origin + (end - origin) * motion_result[0]}


func _current_destination() -> Vector3:
	if is_instance_valid(_target_campfire) and _task == Task.TO_CAMPFIRE:
		return _target_campfire.global_position
	if is_instance_valid(_target_ingredient):
		return _target_ingredient.global_position
	return global_position


func _stand_still(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()


## The closest thing the Chef could gather an ingredient from: a chicken (raw
## meat) or one of the forageable pickups (berries, mushrooms, herbs).
func _nearest_ingredient() -> Node3D:
	var best: Node3D = null
	var best_distance: float = INF
	var groups: Array = ["chickens"]
	groups.append_array(FORAGE_GROUPS.keys())
	for group: String in groups:
		for candidate: Node in get_tree().get_nodes_in_group(group):
			var node: Node3D = candidate as Node3D
			if not is_instance_valid(node):
				continue
			var distance: float = global_position.distance_to(node.global_position)
			if distance < best_distance:
				best_distance = distance
				best = node
	return best


func _nearest_campfire() -> Node3D:
	var best: Node3D = null
	var best_distance: float = INF
	for candidate: Node in get_tree().get_nodes_in_group("placed_campfires"):
		var campfire: Node3D = candidate as Node3D
		if not is_instance_valid(campfire):
			continue
		var distance: float = global_position.distance_to(campfire.global_position)
		if distance < best_distance:
			best_distance = distance
			best = campfire
	return best


func _set_walk_animation(walking: bool) -> void:
	if _animation_player == null:
		return
	var wanted: StringName = _walk_animation if walking else IDLE_ANIMATION
	if _animation_player.has_animation(wanted) and _animation_player.current_animation != String(wanted):
		_animation_player.play(wanted)


func _build_prompt() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "ChefPromptLayer"
	add_child(_prompt_layer)
	_prompt = Label.new()
	_prompt.name = "ChefPrompt"
	_prompt.text = "Chef\nPress E to talk"
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


func _build_dialogue() -> void:
	_dialogue_layer = CanvasLayer.new()
	_dialogue_layer.name = "ChefDialogueLayer"
	_dialogue_layer.layer = 6
	_dialogue_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_dialogue_layer)
	_dialogue_root = CenterContainer.new()
	_dialogue_root.name = "ChefDialogueRoot"
	_dialogue_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialogue_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_root.add_to_group("blocking_ui")
	_dialogue_root.visible = false
	_dialogue_layer.add_child(_dialogue_root)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 230.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.94)
	style.border_color = Color(0.78, 0.22, 0.18, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24.0
	style.content_margin_top = 18.0
	style.content_margin_right = 24.0
	style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", style)
	_dialogue_root.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	var heading: Label = Label.new()
	heading.text = "Chef"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 23)
	content.add_child(heading)
	_dialogue_message = Label.new()
	_dialogue_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialogue_message.add_theme_font_size_override("font_size", 25)
	content.add_child(_dialogue_message)
	_yes_button = Button.new()
	_yes_button.text = "Yes"
	_yes_button.custom_minimum_size = Vector2(0.0, 44.0)
	_yes_button.pressed.connect(_on_yes_pressed)
	content.add_child(_yes_button)
	_no_button = Button.new()
	_no_button.text = "No"
	_no_button.custom_minimum_size = Vector2(0.0, 44.0)
	content.add_child(_no_button)
	var exit_button: Button = Button.new()
	exit_button.text = "Exit"
	exit_button.custom_minimum_size = Vector2(0.0, 40.0)
	exit_button.pressed.connect(_on_exit_pressed)
	content.add_child(exit_button)


func _build_friend_overlay() -> void:
	_friend_layer = CanvasLayer.new()
	_friend_layer.name = "ChefFriendLayer"
	_friend_layer.layer = 8
	_friend_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_friend_layer)
	_friend_overlay = ColorRect.new()
	_friend_overlay.name = "FriendOverlay"
	_friend_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_friend_overlay.color = Color(0.025, 0.055, 0.07, 0.93)
	_friend_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_friend_overlay.visible = false
	_friend_layer.add_child(_friend_overlay)
	var friend_center: CenterContainer = CenterContainer.new()
	friend_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_friend_overlay.add_child(friend_center)
	_friend_message = Label.new()
	_friend_message.text = "You made a friend!"
	_friend_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_friend_message.add_theme_font_size_override("font_size", 56)
	_friend_message.add_theme_color_override("font_color", Color(1.0, 0.83, 0.39, 1.0))
	_friend_message.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_friend_message.add_theme_constant_override("shadow_offset_x", 3)
	_friend_message.add_theme_constant_override("shadow_offset_y", 4)
	friend_center.add_child(_friend_message)


func _show_friend_message() -> void:
	if is_instance_valid(_friend_tween):
		_friend_tween.kill()
	_friend_overlay.visible = true
	_friend_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_friend_message.scale = Vector2(0.82, 0.82)
	_friend_tween = create_tween()
	_friend_tween.set_trans(Tween.TRANS_BACK)
	_friend_tween.set_ease(Tween.EASE_OUT)
	_friend_tween.tween_property(_friend_overlay, "modulate:a", 1.0, 0.35)
	_friend_tween.parallel().tween_property(_friend_message, "scale", Vector2.ONE, 0.45)
	_friend_tween.tween_interval(2.2)
	_friend_tween.tween_property(_friend_overlay, "modulate:a", 0.0, 0.8)
	_friend_tween.tween_callback(_hide_friend_message)


func _hide_friend_message() -> void:
	_friend_overlay.visible = false


## Yes-path: Chef thanks the player, then Exit leaves the dialogue and shows the
## friend message. Afterward he no longer offers dialogue.
func _on_exit_pressed() -> void:
	var was_thanked: bool = _thanked
	_close_dialogue()
	if was_thanked and not _friend_made:
		_friend_made = true
		_show_friend_message()
		_start_helping()


func _open_dialogue() -> void:
	_dialogue_open = true
	var has_campfire: bool = not get_tree().get_nodes_in_group("placed_campfires").is_empty()
	_dialogue_root.visible = true
	if _thanked:
		_dialogue_message.text = "Thank you!"
		_yes_button.visible = false
		_no_button.visible = false
	elif has_campfire:
		_dialogue_message.text = "Can I use your campfire?"
		_yes_button.visible = true
		_no_button.visible = true
	else:
		_dialogue_message.text = "Can you make a campfire, please?"
		_yes_button.visible = false
		_no_button.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_yes_pressed() -> void:
	if _helping or _thanked or not _has_campfire():
		return
	_thanked = true
	_dialogue_message.text = "Thank you!"
	_yes_button.visible = false
	_no_button.visible = false


func _has_campfire() -> bool:
	return not get_tree().get_nodes_in_group("placed_campfires").is_empty()


## Starts Chef's campfire helper loop. Called once the friend message has been shown.
func _start_helping() -> void:
	restore_helper_activity()


func _close_dialogue() -> void:
	_dialogue_open = false
	_dialogue_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func get_save_state() -> Dictionary:
	return {"thanked": _thanked, "friend": _friend_made}

func set_save_state(state: Dictionary) -> void:
	_thanked = bool(state["chef_thanked"])
	_friend_made = bool(state["chef_friend"])
	_carried.clear()
	_work_remaining = GATHER_SECONDS
	_target_ingredient = null
	_target_campfire = null
	_dialogue_open = false
	if is_instance_valid(_dialogue_root): _dialogue_root.visible = false
	if is_instance_valid(_friend_overlay): _friend_overlay.visible = false
	_helping = false
	_task = Task.IDLE
	if _friend_made:
		call_deferred("restore_helper_activity")

func _resume_helper_after_restore() -> void:
	await get_tree().process_frame
	_resolve_runtime_references()
	if _helping:
		_target_ingredient = _nearest_ingredient()
		_target_campfire = _nearest_campfire()
		if _target_campfire == null:
			_task = Task.GATHERING
		if is_instance_valid(_animation_player):
			_set_walk_animation(false)

func get_restore_position() -> Vector3:
	return global_position

func _is_other_ui_open() -> bool:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return false
	var inventory: InventoryUI = current_scene.get_node_or_null("InventoryUI") as InventoryUI
	var crafting: CraftingMenu = current_scene.get_node_or_null("CraftingMenu") as CraftingMenu
	if (is_instance_valid(inventory) and inventory.is_open()) or (is_instance_valid(crafting) and crafting.is_open()):
		return true
	for ui_node: Node in get_tree().get_nodes_in_group("blocking_ui"):
		if ui_node is Control and (ui_node as Control).is_visible_in_tree():
			return true
	return false


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null


func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		meshes.append_array(_find_meshes(child))
	return meshes
