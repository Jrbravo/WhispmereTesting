class_name FarmPlotPlacement
extends Node3D

const MAX_PLACE_DISTANCE: float = 18.0
const MAX_PLAYER_DISTANCE: float = 12.0
const MAX_GROUND_HEIGHT_DELTA: float = 1.5
const MIN_GROUND_NORMAL_Y: float = 0.72
const PLOT_COST: Dictionary = {"Fiber": 1, "Wood": 1}
const FIELD_MESH_SCENE: PackedScene = preload("res://Prefabs/Terrain/EA_M_Env_Field_Mud_01a_PRE.prefab.scn")

var _player: PlayerController
var _inventory: InventoryUI
var _preview_root: Node3D
var _preview_material: StandardMaterial3D
var _hint: Label
var _placement_valid: bool = false
var _placement_position: Vector3 = Vector3.ZERO
var _is_placing: bool = false


func setup(player: PlayerController, inventory: InventoryUI) -> void:
	_player = player
	_inventory = inventory
	_preview_root = FIELD_MESH_SCENE.instantiate() as Node3D
	_preview_root.name = "FarmPlotPreview"
	_preview_root.scale = Vector3.ONE * 0.3
	add_child(_preview_root)
	_preview_material = StandardMaterial3D.new()
	_preview_material.albedo_color = Color(0.35, 1.0, 0.42, 0.58)
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_apply_preview_material(_preview_root)
	_preview_root.visible = false
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "PlacementHintLayer"
	add_child(layer)
	_hint = Label.new()
	_hint.name = "PlacementHint"
	_hint.text = "Farm plot  |  Left click: place  |  Right click: cancel"
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -280.0
	_hint.offset_top = -72.0
	_hint.offset_right = 280.0
	_hint.offset_bottom = -34.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.96, 0.8, 1.0))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	layer.add_child(_hint)
	set_process(true)
	set_physics_process(true)


func begin_placement() -> void:
	if _is_placing or not is_instance_valid(_inventory):
		return
	if not _inventory.can_consume_items(PLOT_COST):
		return
	_is_placing = true
	_preview_root.visible = true
	_hint.visible = true


func _process(_delta: float) -> void:
	if not _is_placing:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(_delta: float) -> void:
	if _is_placing:
		_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_placing or not event is InputEventMouseButton or not event.pressed:
		return
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
		cancel_placement()
		get_viewport().set_input_as_handled()
	elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if _placement_valid:
			_place_plot()
		get_viewport().set_input_as_handled()


func _update_preview() -> void:
	if not is_instance_valid(_player):
		return
	var camera: Camera3D = _player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse_position)
	var direction: Vector3 = camera.project_ray_normal(mouse_position)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * MAX_PLACE_DISTANCE)
	query.exclude = [_player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	_placement_valid = false
	_set_preview_color(Color(1.0, 0.3, 0.25, 0.58))
	if hit.is_empty():
		return
	var normal: Vector3 = hit["normal"] as Vector3
	var hit_position: Vector3 = hit["position"] as Vector3
	var distance: float = Vector2(hit_position.x - _player.global_position.x, hit_position.z - _player.global_position.z).length()
	if normal.dot(Vector3.UP) < MIN_GROUND_NORMAL_Y or distance > MAX_PLAYER_DISTANCE or absf(hit_position.y - _player.global_position.y) > MAX_GROUND_HEIGHT_DELTA:
		return
	_placement_position = hit_position + Vector3.UP * 0.05
	_preview_root.global_position = _placement_position
	_placement_valid = true
	_set_preview_color(Color(0.35, 1.0, 0.42, 0.58))


func _apply_preview_material(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _preview_material
	for child: Node in node.get_children():
		_apply_preview_material(child)


func _set_preview_color(color: Color) -> void:
	_preview_material.albedo_color = color


func _place_plot() -> void:
	if not _inventory.consume_items(PLOT_COST):
		return
	var plot: FarmPlot = FarmPlot.new()
	plot.name = "FarmPlot"
	plot._saved_world_position = _placement_position
	get_tree().current_scene.add_child(plot)
	plot.global_position = _placement_position
	_is_placing = false
	_preview_root.visible = false
	_hint.visible = false


func cancel_placement() -> void:
	_is_placing = false
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and is_instance_valid(_inventory) and not _inventory.is_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(_preview_root):
		_preview_root.visible = false
	if is_instance_valid(_hint):
		_hint.visible = false
