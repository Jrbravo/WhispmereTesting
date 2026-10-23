class_name FarmPlot
extends Node3D

const WATERING_SECONDS: float = 5.0
const GROWTH_SECONDS: float = 60.0
const HARVEST_AMOUNT: int = 3
const INTERACTION_DISTANCE: float = 3.0
const FIELD_MUD_SCENE: PackedScene = preload("res://Prefabs/Terrain/EA_M_Env_Field_Mud_01a_PRE.prefab.scn")

const STAGE_EMPTY: String = "empty"
const STAGE_WATERING: String = "watering"
const STAGE_GROWING: String = "growing"
const STAGE_READY: String = "ready"

var stage: String = STAGE_EMPTY
var remaining_seconds: float = 0.0
var _player: PlayerController
var _inventory: InventoryUI
var _visual_root: Node3D
var _status_layer: CanvasLayer
var _status_label: Label
var _prompt_layer: CanvasLayer
var _prompt: Label
var _status_time: float = 0.0
var _glow_phase: float = 0.0
var _saved_world_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("farm_plots")
	add_to_group("interactable")
	if _saved_world_position != Vector3.ZERO:
		position = _saved_world_position
	else:
		_saved_world_position = position
	_player = get_tree().current_scene.get_node_or_null("Player") as PlayerController
	_inventory = get_tree().current_scene.get_node_or_null("InventoryUI") as InventoryUI
	_build_visuals()
	_build_ui()
	_refresh_visual()
	set_process(true)


func _build_visuals() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "PlotVisual"
	add_child(_visual_root)
	var field: Node3D = FIELD_MUD_SCENE.instantiate() as Node3D
	field.name = "FieldMud"
	field.scale = Vector3.ONE * 0.3
	field.position.y = 0.05
	_visual_root.add_child(field)


func _build_ui() -> void:
	_status_layer = CanvasLayer.new()
	_status_layer.name = "FarmStatusLayer"
	_status_layer.layer = 7
	add_child(_status_layer)
	_status_label = Label.new()
	_status_label.name = "FarmStatus"
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_status_label.offset_left = -250.0
	_status_label.offset_top = 95.0
	_status_label.offset_right = 250.0
	_status_label.offset_bottom = 140.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 24)
	_status_label.add_theme_color_override("font_color", Color(0.72, 1.0, 0.68, 1.0))
	_status_label.add_theme_color_override("font_shadow_color", Color(0.2, 1.0, 0.45, 0.9))
	_status_label.add_theme_constant_override("shadow_offset_x", 1)
	_status_label.add_theme_constant_override("shadow_offset_y", 1)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.visible = false
	_status_layer.add_child(_status_label)
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "FarmPromptLayer"
	_prompt_layer.layer = 6
	add_child(_prompt_layer)
	_prompt = Label.new()
	_prompt.name = "FarmPrompt"
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_prompt.offset_top = 28.0
	_prompt.offset_bottom = 80.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.93, 0.65, 1.0))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	_prompt_layer.add_child(_prompt)


func _process(delta: float) -> void:
	if SaveManager.is_restoring():
		return
	if not is_instance_valid(_player) and get_tree().current_scene != null:
		_player = get_tree().current_scene.get_node_or_null("Player") as PlayerController
	if not is_instance_valid(_inventory):
		_inventory = get_tree().current_scene.get_node_or_null("InventoryUI") as InventoryUI
	if stage == STAGE_WATERING:
		remaining_seconds = maxf(0.0, remaining_seconds - delta)
		_status_time = maxf(0.0, _status_time - delta)
		_glow_phase += delta * 7.0
		if is_instance_valid(_status_label):
			_status_label.text = "Watering your plot!  %.0f" % ceili(remaining_seconds)
			_status_label.modulate = Color(1.0, 0.75 + 0.25 * absf(sin(_glow_phase)), 0.58 + 0.42 * absf(sin(_glow_phase)), 1.0)
		if remaining_seconds <= 0.0:
			finish_watering()
	elif stage == STAGE_GROWING:
		remaining_seconds = maxf(0.0, remaining_seconds - delta)
		if remaining_seconds <= 0.0:
			stage = STAGE_READY
			remaining_seconds = 0.0
			_refresh_visual()
	_refresh_prompt()


func _refresh_prompt() -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_prompt):
		return
	var flat_position: Vector3 = Vector3(_player.global_position.x, global_position.y, _player.global_position.z)
	var in_range: bool = flat_position.distance_to(global_position) <= INTERACTION_DISTANCE and InteractionArbiter.is_selected(self)
	_prompt.visible = in_range and stage != STAGE_WATERING and not _any_menu_open()
	if _status_time > 0.0 and stage != STAGE_WATERING:
		_status_time = maxf(0.0, _status_time - get_process_delta_time())
		if _status_time <= 0.0:
			return
		_prompt.text = "Make room for all 3 Wild Berries!"
		_prompt.visible = in_range
		return
	if not in_range:
		return
	match stage:
		STAGE_EMPTY: _prompt.text = "Farm Plot\nE: plant Wild Berries"
		STAGE_GROWING: _prompt.text = "Farm Plot\nGrowing: %d seconds" % ceili(remaining_seconds)
		STAGE_READY: _prompt.text = "Farm Plot\nE: harvest 3 Wild Berries"
		_: _prompt.text = "Farm Plot"
	if in_range and InteractionArbiter.is_selected(self) and Input.is_action_just_pressed("pickup") and not _any_menu_open():
		if stage == STAGE_EMPTY:
			_start_watering()
		elif stage == STAGE_READY:
			_harvest()


func _any_menu_open() -> bool:
	if not is_instance_valid(_inventory):
		return false
	var crafting: CraftingMenu = get_tree().current_scene.get_node_or_null("CraftingMenu") as CraftingMenu
	return _inventory.is_open() or (is_instance_valid(crafting) and crafting.is_open())


func _start_watering() -> bool:
	if stage != STAGE_EMPTY or not is_instance_valid(_inventory) or not _inventory.remove_item("Wild Berries", 1):
		return false
	_begin_watering()
	return true


func start_farmer_watering(chest: ChestInventoryMenu) -> bool:
	if stage != STAGE_EMPTY or not is_instance_valid(chest) or not chest.remove_berry(1):
		return false
	_begin_watering()
	return true


func _begin_watering() -> void:
	stage = STAGE_WATERING
	remaining_seconds = WATERING_SECONDS
	_status_time = WATERING_SECONDS
	_glow_phase = 0.0
	if is_instance_valid(_status_label):
		_status_label.visible = true
		_status_label.text = "Watering your plot!  5"
	if is_instance_valid(_player) and is_instance_valid(_inventory):
		_player.begin_farm_watering()
	_refresh_visual()


func finish_watering() -> void:
	if stage != STAGE_WATERING:
		return
	stage = STAGE_GROWING
	remaining_seconds = GROWTH_SECONDS
	if is_instance_valid(_status_label):
		_status_label.visible = false
	if is_instance_valid(_player):
		_player.end_farm_watering()
	_refresh_visual()


func _harvest() -> bool:
	if stage != STAGE_READY or not is_instance_valid(_inventory):
		return false
	if not _inventory.can_add_item_bundle({"Wild Berries": HARVEST_AMOUNT}):
		if is_instance_valid(_prompt):
			_prompt.text = "Make room for all 3 Wild Berries!"
			_prompt.visible = true
		_status_time = 3.0
		return false
	if _inventory.add_berry(HARVEST_AMOUNT) != HARVEST_AMOUNT:
		return false
	stage = STAGE_EMPTY
	remaining_seconds = 0.0
	_refresh_visual()
	return true


func harvest_to_chest(chest: ChestInventoryMenu) -> bool:
	if stage != STAGE_READY or not is_instance_valid(chest) or not chest.can_add_berry(HARVEST_AMOUNT):
		return false
	if chest.add_berry(HARVEST_AMOUNT) != HARVEST_AMOUNT:
		return false
	stage = STAGE_EMPTY
	remaining_seconds = 0.0
	_refresh_visual()
	return true


func _refresh_visual() -> void:
	if not is_instance_valid(_visual_root):
		return
	for child: Node in _visual_root.get_children():
		_visual_root.remove_child(child)
		child.queue_free()
	var field: Node3D = FIELD_MUD_SCENE.instantiate() as Node3D
	field.name = "FieldMud"
	field.scale = Vector3.ONE * 0.3
	field.position.y = 0.05
	_visual_root.add_child(field)
	if stage == STAGE_READY:
		var marker: MeshInstance3D = MeshInstance3D.new()
		marker.name = "ReadySpark"
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.18
		sphere.height = 0.36
		marker.mesh = sphere
		var glow: StandardMaterial3D = StandardMaterial3D.new()
		glow.albedo_color = Color(0.48, 1.0, 0.3, 1.0)
		glow.emission_enabled = true
		glow.emission = Color(0.35, 1.0, 0.2, 1.0)
		marker.material_override = glow
		marker.position = Vector3(0.0, 0.9, 0.0)
		_visual_root.add_child(marker)
	elif stage == STAGE_GROWING:
		var sprout: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.34
		sprout.mesh = sphere
		var leaf: StandardMaterial3D = StandardMaterial3D.new()
		leaf.albedo_color = Color(0.2, 0.65, 0.22, 1.0)
		sprout.material_override = leaf
		sprout.position = Vector3(0.0, 0.28, 0.0)
		_visual_root.add_child(sprout)


func get_save_state() -> Dictionary:
	var save_position: Vector3 = position if not is_inside_tree() else global_position
	return {"position": [save_position.x, save_position.y, save_position.z], "stage": stage, "remaining": remaining_seconds}


func set_save_state(state: Dictionary) -> void:
	if stage == STAGE_WATERING and is_instance_valid(_player):
		_player.end_farm_watering()
	var position_value: Array = state.get("position", [0.0, 0.0, 0.0])
	if position_value.size() == 3:
		_saved_world_position = Vector3(float(position_value[0]), float(position_value[1]), float(position_value[2]))
		if is_inside_tree():
			global_position = _saved_world_position
		else:
			position = _saved_world_position
	stage = String(state.get("stage", STAGE_EMPTY))
	remaining_seconds = maxf(0.0, float(state.get("remaining", 0.0)))
	if stage == STAGE_WATERING:
		if is_instance_valid(_status_label):
			_status_label.visible = true
			_status_label.text = "Watering your plot!  %d" % ceili(remaining_seconds)
		if is_instance_valid(_player):
			_player.begin_farm_watering()
	elif stage == STAGE_GROWING and remaining_seconds <= 0.0:
		stage = STAGE_READY
	_refresh_visual()


func interact() -> void:
	if stage == STAGE_WATERING:
		return
	if stage == STAGE_EMPTY:
		_start_watering()
	elif stage == STAGE_READY:
		_harvest()


func interaction_point() -> Vector3:
	return global_position


func interaction_radius() -> float:
	return INTERACTION_DISTANCE


func is_interaction_actionable() -> bool:
	return true
